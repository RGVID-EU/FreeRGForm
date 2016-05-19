#!/usr/bin/perl

use v5.10;
use strict;
use warnings;
use CGI qw(:standard);
use utf8;
use CGI::Carp qw(fatalsToBrowser);
use Digest::SHA qw(sha256_hex);
use Encode qw(decode encode);
use JSON::XS;
use File::Temp qw(tempfile tempdir);
use File::Copy 'mv';
use Crypt::Random::Seed;
use CGI::Cookie;

my $q = CGI->new;
my $coder = JSON::XS->new->pretty;
my $random = Crypt::Random::Seed->new(NonBlocking => 1) // die "No random sources exist";
my $mainFolder = '../data';
my $formsFolder = "$mainFolder/forms";
my $tmpFolder = "$mainFolder/tmp";
my $nowString = localtime;
my $formId = getParam('formId');
my $apparatus = getParam('apparatus');
my @allApparatus = qw (freehands hoop rope ball clubs ribbon);
my %params = $q->Vars;
my %cookies = CGI::Cookie->fetch;

if ($ENV{'REQUEST_METHOD'} ne 'POST') {
    print $q->header(-charset => 'UTF-8');
    print "Error. Something went wrong.";
    exit 0;
}

my $formContainsElements = 0;
for (my $i = 1; $i <= 36; $i++) {
    if (getParam("symbolsInForm$i") ne '') {
	$formContainsElements = 1;
	last;
    }
}

if (!$formContainsElements) {
    print $q->header(-charset => 'UTF-8');
    print "Save error. Please add at least one element to the form.";
    exit 0;
}

my $cookieHash = '';

my $newData = $coder->encode(\%params);
utf8::decode($newData);

unless (-d $formsFolder) {
    mkdir $formsFolder;
}

if ($formId eq '') {
    checkApparatus($apparatus);
    my $secret = $random->random_bytes(32);
    $secret = unpack "H*", $secret;
    my $hash = sha256_hex($secret);
    $cookieHash = CGI::Cookie->new(-name=> $hash,-value=> $secret, -expires =>  '+10y');
    print $q->header(-charset => 'UTF-8', -cookie => $cookieHash);
    my $formFolder = "$formsFolder/$hash";
    unless (-d $formFolder) {
	mkdir $formFolder;
    }
    my $formFile = "$formFolder/form.json";

    print encode("utf8", $hash);
    unless(open FILE, '>'.$formFile) {
	die "\nUnable to create $formFile\n";
    }
    writeStringToFile($formFile, $newData);
} else {
    checkApparatus($apparatus);
    print $q->header(-charset => 'UTF-8');
    if (!canEdit($formId)) {
	print "Error. Something went wrong.";
	exit 0;
    }
    my $formFolder = "$formsFolder/$formId";
    unless (-d $formFolder) {
	mkdir $formFolder;
    }
    #check if file exists
    my $formFile = "$formFolder/form.json";
    unless (-e $formFile) {
	print "Error. Something went wrong.";
	exit 0;
    }
    writeStringToFile($formFile, $newData);
    print "$formId";
}

sub writeStringToFile {
    my ($file, $string) = @_;
    utf8::encode($file);
    unless (-d $tmpFolder) {mkdir $tmpFolder;}
    my ($TEMP, $tempFile) = tempfile(DIR => $tmpFolder);
    chmod(0660, $tempFile);
    binmode($TEMP, ':encoding(UTF-8)');
    print $TEMP $string;
    close($TEMP);
    mv($tempFile, $file) or die "Move failed: $!";
}

sub getParam {
    my ($param) = @_;
    my $result = $q->param($param);
    return '' unless defined $result; # TODO undefs are ok too
    $result = escapeHTML($result);
    return $result;
}

sub canEdit {
    my ($formIdParam) = @_;
    if ($formIdParam ne '') { $formId = $formIdParam; }

    if ( exists $cookies{$formId} ) {
	if ($cookies{$formId}->name eq sha256_hex($cookies{$formId}->value)) {
	    return 1;
	}
    } else {
	return 0;
    }
}

sub checkApparatus {
    my ($apparatusParam) = @_;
    if (!grep( /^$apparatusParam$/, @allApparatus )) {
	print $q->header(-charset => 'UTF-8');
	print "Error. Apparatus not chosen.";
	exit 0;
    }
}
