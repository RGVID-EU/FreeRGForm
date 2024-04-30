#!/usr/bin/perl

use v5.10;
use strict;
use warnings;
use CGI qw(:standard);
use utf8;
use open ':std', ':utf8';  # STDIN,STOUT,STERR is UTF-8.
use CGI::Carp qw(fatalsToBrowser);
use Encode qw(decode encode);
use File::Basename;
use File::stat;
use Time::localtime;
use DateTime;
use Fcntl ':mode';
use POSIX qw{strftime};
use CGI::Cookie;
use Digest::SHA qw(sha256_hex);
use HTML::Tiny;
use JSON::XS;
use File::Temp qw(tempfile tempdir mktemp);
use File::Copy 'mv';
use Time::HiRes qw(time);

my $mainFolder = '/srv/data';
my $formsFolder = "$mainFolder/forms";
my $lock = "$mainFolder/lockFolder";
my $tmpFolder = "$mainFolder/tmp";
my $q = CGI->new;
my @searchResults;
my $action = getParam('action');
my $comment = getParam('commentForm');
my $commenter = getParam('commenter');
my $commenterIP = $q->remote_host();
my $cookiesCommenter = '';
my $TEMP = '';
my $tempFile = '';
if ($comment ne '') {
    $cookiesCommenter = CGI::Cookie->new(-name=> 'commenter', -value=> $commenter, -expires =>  '+10y');
}

my $csp = "default-src 'none'; script-src 'self'; connect-src 'self'; img-src 'self'; style-src 'self'; font-src 'self'";

if (getParam('pdf')) {
    print $q->header(-charset => 'UTF-8', -type => 'application/pdf');
} else {
    print $q->header(-charset => 'UTF-8', -cookie => $cookiesCommenter,
		     '-Content-Security-Policy' => $csp, '-X-Content-Security-Policy' => $csp, '-X-Webkit-CSP' => $csp);
}

my %cookies = CGI::Cookie->fetch;
my $secretName = 'HIDDEN';
my $coder = JSON::XS->new->pretty;
my $queryRegex = '^[\p{L} 0-9-]+$';
my $query = getParam('query');
my $lcQuery = lc $query;
my $h = HTML::Tiny->new;
my %formData = ();
my $gymnastsName = $formData{'gymnastsName'};
my @comments;

my %logos;
$logos{'freehands'} = '󸣿';
$logos{'rope'} = '󸤁';
$logos{'hoop'} = '󸤀';
$logos{'ball'} = '󸤂';
$logos{'clubs'} = '󸤃';
$logos{'ribbon'} = '󸤄';

my $formId = getParam('id');
my $formCommentsFolder = "$formsFolder/$formId";
my $formCommentsFile = "$formCommentsFolder/comments.json";
if ($formId ne '') {

    #TODO error for shorter/longer hash?

    my $formFile = "$formsFolder/$formId/form.json";
    unless (-e $formFile) {
	print $h->div('Error. Form not found.');
	exit 0;
    }

    %formData =  getHashFromFile($formFile);

    my $gymnastsNameHidden = $formData{'hideName'};
    $gymnastsName = $formData{'gymnastsName'};
    if (!canEdit($formId) && ($gymnastsNameHidden // '') eq 'on') {
	$gymnastsName = $secretName;
    }
}

my $hiddenName = '';

my $tablecontent;

push @$tablecontent, $h->open('tr', {class => 'formDataRow changeFontSize'});
push @$tablecontent, $h->td($h->span('Individual Exercise Difficulty (D)'));
push @$tablecontent, $h->td($h->span('Judge № '  . $h->input({class => 'shortInput', name => 'judge',
							      value => ($formData{'judge'} // ''), tabindex => 1})));
push @$tablecontent, $h->td($h->span('Date: '  . $h->input({class => 'middleInput',
							    class =>'shortInput', name => 'date', value => ($formData{'date'} // ''),
							    maxlength => 14, tabindex => 1})));
push @$tablecontent, $h->close('tr');

push @$tablecontent, $h->open('tr', {class => 'formDataRow changeFontSize'});
push @$tablecontent, $h->td({class => 'NFandYear'}, $h->div('NF:'. $h->input({class => 'shortInput', name => 'NF', value => ($formData{'NF'} // ''),
									      maxlength => 8, tabindex => 1})) .

			    $h->div( "Category:" . $h->input({class => 'shortInput', name => 'year', value => ($formData{'year'} // ''),
							      maxlength => 14, tabindex => 1}))
    );
push @$tablecontent, $h->td($h->div({id => 'gymnastsNameLabel'},'Gymnast:') . $h->div($h->input({class => 'nameInput', name => 'gymnastsName', value => $gymnastsName, maxlength => 30, tabindex => 1})) );
push @$tablecontent, $h->td({id => 'apparatusChoice'},printRoutineLogo());
push @$tablecontent, $h->close('tr');


push @$tablecontent, $h->open('tr');
for (my $i = 1; $i <=3; $i++) {
    push @$tablecontent, $h->td({class => 'mainFormTableCell'},'Difficulty'
	);
}
push @$tablecontent, $h->close('tr');

for (my $i = 0; $i <= 11; $i++) {
    push @$tablecontent, $h->open('tr');
    for (my $j = 1; $j <= 3; $j++) {
	my $cellNo;
	if ($j == 1) { $cellNo = $i+$j;}
	if ($j == 2) { $cellNo = $i+$j + 11;}
	if ($j == 3) { $cellNo = $i+$j + 22;}

	push @$tablecontent, generateTableBlock($cellNo);
    }
    push @$tablecontent, $h->close('tr');
}

push @$tablecontent, $h->open('tr', {class => 'formDataRow changeFontSize'});

my $musicWithWords = '';

if (($formData{'musicWithWords'} // '') eq 'on') {
    $musicWithWords = 'checked';
}

push @$tablecontent, $h->td(
    [$h->label({for => 'musicWithWordsCheckBox', id => 'musicWithWordsText'},'Use music with voice and words: '),
     $h->closed( 'input', { type => 'checkbox', name => 'musicWithWords', id => 'musicWithWordsCheckBox', class => $musicWithWords, tabindex => 50 } )]
    );


push @$tablecontent, $h->td([
    $h->ul({class => 'noBullets fundamental'},[
	       $h->li('Fundamental: ' . $h->input({class => 'fundamentalInput', name => 'fundamentalElements', id => 'fundamentalElements',
						   value => ($formData{'fundamentalElements'} // ''),
						   maxlength => 2, tabindex => 50}) . $h->span({id => 'fundamentalsPercent'}, '')),
	       $h->li('Other: ' . $h->input({class => 'fundamentalInput', name => 'otherElements', id => 'otherElements',
					     value => ($formData{'otherElements'} // ''), maxlength => 2, tabindex => 50}))
	   ]
    )
			    ]);
push @$tablecontent, $h->td('TOTAL' .
			    $h->input({name => 'total', class => 'totalInput', value => ($formData{'total'} // ''), maxlength => 4, tabindex => 50}));
push @$tablecontent, $h->close('tr');

push @$tablecontent, $h->open('tr', {class => 'formDataRow penaltiesRow'});
push @$tablecontent, $h->td({class => 'penalties'},[
				$h->span('0.30 p. penalties:'),
				$h->ul({class => 'renameMe'},[
					   $h->li('Less than 2/more than 4 Difficulties of each Body Group (penalty for each)'),
					   $h->li(['Incorrect calculation:',
						   $h->ul({class => 'renameMe'},[
							      $h->li('Total value of all the Difficulties'),
							      $h->li('Value of each Difficulty component'),
							  ])
						  ]),
					   $h->li('More than one “slow turn”'),
					   $h->li(['For each Difficulty performed but not declared on the official form. Except Difficulty with value 0.10 :',
						   $h->ul({class => 'renameMe'},[
							      $h->li('With rotation used in DER and Mastery'),
							      $h->li('With or without rotation used in Dance Steps'),
							  ])
						  ]),
				       ]
				)]);
push @$tablecontent, $h->td({class => 'penalties'},[
				$h->span('0.50 p. penalties:'),
				$h->ul({class => 'renameMe'},[
					   $h->li('More  than 9 Difficulties declared'),
					   $h->li('Min. 1 '. $h->span({class=>'symbolsInPenalties'},'󸣱')),
					   $h->li('Max. 3 '. $h->span({class=>'symbolsInPenalties'},'󸣘') . ', Max 5 Mastery'),
					   $h->li('For absence of Fundamental groups predominance (less than 50%)'),
					   $h->li('More than one exercise with music with voice and words'),
					   $h->li('Use of music with words without indication on the D-Form'),
				       ]),
				$h->input({id => 'formId', name => 'formId', value => getFormId() , hidden => 'hidden'
					  }),
			    ]);

push @$tablecontent, $h->td({id => 'penaltyRight'},$h->table({id => 'penaltyAndFinalScore'},[
								 $h->tr($h->td({id => 'finalPenalty'},'Penalty')),
								 $h->tr($h->td({id =>'finalScoreJudge'},'FINAL SCORE JUDGE')),
							     ]));
push @$tablecontent, $h->close('tr');

my %difficulties;
$difficulties{'jumps'} =
    [
     [ ['1. Vertical Jumps with rotation of the body on 180°, as well as 360°'], [qw{󱎈 󱎉 󱎊 󱎋 󱎌 󱎍}], [qw{󱎎 󱎏 󱎐 󱎑 󱎒}], [qw{}], [qw{}], [qw{}] ],
     [ ['2. "Cabriole" (forward, side, backwards); arch'], [qw{󱎓 󱎔}], [qw{}], [qw{}], [qw{}], [qw{}] ],
     [ ['3. "Scissor" Leaps witd switch of legs in various positions; in ring'], [qw{󱎕 󱎖}], [qw{󱎗}], [qw{󱎘}], [qw{}], [qw{}] ],
     [ ['4. Pike jump. Straddle jumps.'], [qw{}], [qw{}], [qw{󱎙 󱎚}], [qw{󱎛}], [qw{}] ],
     [ ['5. "Cossack" Legs in various positions; in ring'], [qw{󱎞}], [qw{󱎠 󱎢}], [qw{󱎦}], [qw{}], [qw{}] ],
     [ ['6. Ring'], [qw{󱎨}], [qw{}], [qw{}], [qw{󱎪}], [qw{}] ],
     [ ['7. "Fouetté" Legs in various position'], [qw{}], [qw{󱎬 󱎮}], [qw{󱎰 󱎲 󱎴 󱎶}], [qw{}], [qw{󱎷}] ],
     [ ['8. "Entrelacé". Legs in various positions'], [qw{}], [qw{}], [qw{}], [qw{󱎹}], [qw{󱎻 󱎽}]  ],
     [ ['9. Split and stag leaps in: ring; withback bend; with trunk rotation. These Jumps/Leaps, performed with take-off from 1 or 2 feet, are considered asdifferent Difficulties.In case of take-off 2 feet, the arrow should be added below the Jump symbol'], [qw{󱎿}], [qw{󱏈 󱏋 󱏂}], [qw{󱏍 󱏓}], [qw{󱏖 󱏙}], [qw{󱏚}] ],
     [ ['10. Turning split leaps -legs in various positions, according criteria'], [qw{}], [qw{}], [qw{󱐃}], [qw{󱐄}], [qw{󱏻}] ],
     [ ['11. "Butterfly"'], [qw{}], [qw{}], [qw{}], [qw{}], [qw{󱐇}] ],
    ];

$difficulties{'balances'} =
    [
     [ ['1. "Passé". Free leg below horizontal with body bent forward or backward '], [qw{󳪚 󳪝 󳪠}], [qw{}], [qw{}], [qw{}], [qw{}] ],
     [ ['2. Free leg at the horizontal in different directions, body bent forwards, backwards, sideways '], [qw{}], [qw{󳪣 󳪦}], [qw{󳪩 󳪬}], [qw{󳪯 󳪲 󳪵 󳪸 󳪻}], [qw{}] ],
     [ ['3. Free leg high up in different directions; body at the horizontal level or below, with or without help '], [qw{}], [qw{󳫁 󳪾}], [qw{󳫐 󳫓 󳫄 󳫇}], [qw{󳫊 󳫍 󳫙 󳫖 󳫜}], [qw{󳫟 󳫢 󳫨 󳫥 󳫫}] ],
     [ ['4. Fouetté (min. 3 different shapes without help of the hands, on "relevé" (every time with heel support) with a minimum of 1 turn of 90° or 180° ). Each Balance shape must be clearly fixed. '], [qw{}], [qw{}], [qw{󳫬}], [qw{}], [qw{󳫭}] ],
     [ ['5. "Cossack:" free leg at: horizontal level; high up; with gymnast changing level '], [qw{󳫮}], [qw{󳫯 󳫰}], [qw{}], [qw{}], [qw{}] ],
     [ ['6. Balances with support on various parts of the body '], [qw{󳫱 󳫲 󳫳 󳫴}], [qw{󳫵}], [qw{󳫶}], [qw{}], [qw{}] ],
     [ ['7. Dynamic balance with full body wave '], [qw{󳫷 󳫸}], [qw{}], [qw{󳫹}], [qw{}], [qw{}] ],
     [ ['8. Dynamic balance with or without leg movement with support on various parts of the body. '], [qw{󳫺}], [qw{󳫻}], [qw{}], [qw{󳫼 󳫽 󳫾 󳫿 󳬀}], [qw{󳬁}] ],
    ];

$difficulties{'rotations'} =
    [
     [ ['1.
"Passé". Free leg below horizontal,body bent forward or backward; Spiral turn with wave ("tonneau")'], [qw{󶆨 󶆩 󶆩 󶆫}], [qw{}], [qw{󶆬}], [qw{}], [qw{}] ],
     [ ['2. Free leg straight or bent on the horizontal level; body bent on the horizontal level.'],
       [qw{}], [qw{󶆭 󶆮 󶆯 󶆰}], [qw{󶆱 󶆲 󶆳}], [qw{󶇕 󶆴 󶆵 󶆶}], [qw{}] ],
     [ ['3. Free leg high up with or without help; body bent on the horizontal level or below horizontal'], [qw{}], [qw{󶆷 󶆸}], [qw{󶆹 󶆺 󶆻 󶆼}],
       [qw{󶆽 󶆾 󶆿 󶇀 󶇁 󶇂}], [qw{󶇃 󶇄 󶇅 󶇆 󶇇 󶇈}] ],
     [ ['4. "Cossack" (free leg on the horizontal level); body bent forwards.'],
       [qw{󶇉}], [qw{󶇊}], [qw{}], [qw{}], [qw{}] ],
     [ ['5. "Fouetté"'], [qw{󶇋}], [qw{󶇌}], [qw{}], [qw{}], [qw{}] ],
     [ ['6. "Illusion" forward, side, backwards; Spiral turn with full body wave; "penché" rotation'], [qw{󶇍 󶇏}], [qw{}], [qw{󶇎}], [qw{󶇐}], [qw{}] ],
     [ ['7. Rotation on various parts of the body'], [qw{󶇑}], [qw{}], [qw{󶇒 󶇓}], [qw{󶇔}], [qw{}] ],
    ];

my @other = [
    [ qw{󸣘 󸣙 󸣚 󸣛 󸣜 󸢸 󸣄 󸣃 󸣝 󸣌 󸣍 󸣞 󸣟 󸣎 󸣏 󸣠 󸣢 󸣡 󸣣 󸣇 󸢽 󸣶 󸣷 󸣸 󸣹 󸣺 󸣻 󸣼 󸣽 󸣾}],
    [ qw{󸣭 󸣮 󸣯 󸣚 󸣛 󸣤 󸣥 󸣦 󸣧 󸣨 󸣩 󸣢 󸣪 󸣣 󸣍 󸣞 󸣡 󸣠}],
    [ qw{󸣱 󸣫 󸣬 󸣮 󸣯 󸣰 󸣲 󸣳 󸣴 󸣵 󳬃}],
    ];

my @allElements = [
    [    qw{󱎈 󱎉 󱎊 󱎋 󱎌 󱎍 󱎎 󱎏 󱎐 󱎑 󱎒 󱎓 󱎔 󱎕 󱎖 󱎗 󱎘 󱎙 󱎚 󱎛 󱎜 󱎝 󱎞 󱎟 󱎠 󱎡 󱎢 󱎣 󱎤 󱎥 󱎦 󱎧 󱎨 󱎩 󱎪 󱎫 󱎬 󱎭 󱎮 󱎯 󱎰 󱎱 󱎲 󱎳 󱎴 󱎵 󱎶 󱎷 󱎸 󱎹 󱎺 󱎻 󱎼 󱎽 󱎾 󱎿 󱏀 󱏁 󱏂 󱏃 󱏄 󱏅 󱏆 󱏇 󱏈 󱏉 󱏊 󱏋 󱏌 󱏍 󱏎 󱏏 󱏐 󱏑 󱏒 󱏓 󱏔 󱏕 󱏖 󱏗 󱏘 󱏙 󱏚 󱏛 󱏜 󱏝 󱏞 󱏟 󱏠 󱏡 󱏢 󱏣 󱏤 󱏥 󱏦 󱏧 󱏨 󱏩 󱏪 󱏫 󱏬 󱏭 󱏮 󱏯 󱏰 󱏱 󱏲 󱏳 󱏴 󱏵 󱏶 󱏷 󱏸 󱏹 󱏺 󱏻 󱏼 󱏽 󱏾 󱏿 󱐀 󱐁 󱐂 󱐃 󱐄 󱐅 󱐆 󱐇}],
    [qw{󳪘 󳪙 󳪚 󳪛 󳪜 󳪝 󳪞 󳪟 󳪠 󳪡 󳪢 󳪣 󳪤 󳪥 󳪦 󳪧 󳪨 󳪩 󳪪 󳪫 󳪬 󳪭 󳪮 󳪯 󳪰 󳪱 󳪲 󳪳 󳪴 󳪵 󳪶 󳪷 󳪸 󳪹 󳪺 󳪻 󳪼 󳪽 󳪾 󳪿 󳫀 󳫁 󳫂 󳫃 󳫄 󳫅 󳫆 󳫇 󳫈 󳫉 󳫊 󳫋 󳫌 󳫍 󳫎 󳫏 󳫐 󳫑 󳫒 󳫓 󳫔 󳫕 󳫖 󳫗 󳫘 󳫙 󳫚 󳫛 󳫜 󳫝 󳫞 󳫟 󳫠 󳫡 󳫢 󳫣 󳫤 󳫥 󳫦 󳫧 󳫨 󳫩 󳫪 󳫫 󳫬 󳫭 󳫮 󳫯 󳫰 󳫱 󳫲 󳫳 󳫴 󳫵 󳫶 󳫷 󳫸 󳫹 󳫺 󳫻 󳫼 󳫽 󳫾 󳫿 󳬀 󳬁 󳬂}],
    [ qw{󶆨 󶆩 󶆪 󶆫 󶆬 󶆭 󶆮 󶆯 󶆰 󶆱 󶆲 󶆳 󶇕 󶆴 󶆵 󶆶 󶆷 󶆸 󶆹 󶆺 󶆻 󶆼 󶆽 󶆾 󶆿 󶇀 󶇁 󶇂 󶇃 󶇄 󶇅 󶇆 󶇇 󶇈 󶇉 󶇊 󶇋 󶇌 󶇍 󶇎 󶇏 󶇐 󶇑 󶇒 󶇓 󶇔}],
    [qw{󸢸 󸢹 󸢺 󸢻 󸢼 󸢽 󸢾 󸢿 󸣀 󸣁 󸣂 󸣃 󸣄 󸣅 󸣆 󸣇 󸣈 󸣉 󸣊 󸣋 󸣌 󸣍 󸣎 󸣏 󸣐 󸣑 󸣒 󸣓 󸣔 󸣕 󸣖 󸣗}],
    [qw{󸣘 󸣙 󸣚 󸣛 󸣜 󸢸 󸣄 󸣃 󸣝 󸣌 󸣍 󸣞 󸣟 󸣎 󸣏 󸣠 󸣢 󸣡 󸣣 󸣇 󸢽 󸣶 󸣷 󸣸 󸣹 󸣺 󸣻 󸣼 󸣽 󸣾}],
    [qw{󸣭 󸣮 󸣯 󸣚 󸣛 󸣤 󸣥 󸣦 󸣧 󸣨 󸣩 󸣢 󸣪 󸣣 󸣍 󸣞 󸣡 󸣠}],
    [qw {󸣱 󸣫 󸣬 󸣮 󸣯 󸣰 󸣲 󸣳 󸣴 󸣵 󳬃}],
    ];

my @apparatus = [
    [ ['rope'], [qw{󸢸 󸢹 󸢺 󸢻 󸢼 󸢽}], [qw{󸢾 󸢿 󸣀}] ],
    [ ['hoop'], [qw{󸢸 󸣁 󸣂 󸢾 󸣃 󸣄}], [qw{󸣅 󸢿}] ],
    [ ['ball'], [qw{󸣁 󸣂 󸣆 󸢼 󸣇}], [qw{󸣀 󸢿}] ],
    [ ['clubs'], [qw{󸣈 󸣉 󸣊 󸣋}], [qw{󸢾 󸣀 󸢿 󸣌 󸣍 󸣎 󸣏}] ],
    [ ['ribbon'], [qw{󸣐 󸣑 󸢹 󸣒 󸣓 󸢺}], [qw{󸣔 󸣀 󸢿}] ],
    [ ['all apparatus'], [qw{}], [qw{󸣕 󸣖 󸣀 󸣗}] ],
    ];

if (getParam('pdf')) {
    mkdir $tmpFolder unless -d $tmpFolder;
    ($TEMP, $tempFile) = tempfile(SUFFIX => '.html', DIR => $tmpFolder); # HTML file
    chmod(0660, $tempFile);
    binmode($TEMP, ':encoding(UTF-8)');
    select $TEMP;
}

print "<!DOCTYPE html>";
print $h->open('html');
my $htdocs = getParam('pdf') ? '../../htdocs' : ''; # TODO why current dir is data/tmp ?
print $h->head([ $h->title( showNameInTitle() || 'Rhythmic gymnastics individual routine scripting' ),
		 $h->link({ href =>  "$htdocs/css/w3.css", rel=>'stylesheet', type => 'text/css' }),
		 $h->link({ href =>  "$htdocs/css/my.css", rel=>'stylesheet', type => 'text/css' }),
		 $h->script({ src => "$htdocs/js/jquery-2.1.4.min.js",        type => 'text/javascript' }),
		 $h->script({ src => "$htdocs/js/my.js",                      type => 'text/javascript' }),
		 $h->script({ src => "$htdocs/js/punycode.js",                type => 'text/javascript' }),
	       ]
    );

print $h->open('body');
my $disableInputsStatus = '';
print $h->div({id => 'navbar'}, [
		  $h->ul([
		      $h->li($h->a({tabindex => 1, href => '/', id => 'homeLink'},'Home')),
		      $h->li($h->a({tabindex => 1, href => '/myforms', id => 'myFormsLink'},'My Forms')),
		      $h->li($h->a({tabindex => 1, href => '/help', id => 'helpLink'},'Help')),
		      $h->li($h->a({tabindex => 1, href => '/changes', id => 'recentChangesLink'},'Recent Changes')),
		      $h->li($h->a({tabindex => 1, href => '/comments', id => 'commentsLink'},'Recent Comments')),
		      $h->li($h->a({tabindex => 1, href => '/search', id => 'searchLink'},'Search')),
		      $h->li($h->a({tabindex => 1, id => 'donateBtn', href => '/donate', id => 'donateLink'},'Donate')),
		      $h->li($h->a({tabindex => 1, href => '/contact', id => 'contactLink'},'Contact')),
			 ])
	      ]);
print $h->h1({id => 'mainHeading'},'Free RG Form');

if (defined $q->param('query')) {
    printSearchForm();

    if (length($lcQuery) > 64) {
	my $error = 'Query must be shorter than 65 symbols.';
	printErrorCloseBodyAndExit($error);
    }

    if ($lcQuery eq '') {
	my $error = 'What are you looking for? :)';
	printErrorCloseBodyAndExit($error);
    }

    if ($lcQuery!~ /$queryRegex/) {
	my $error = 'Only letters , numbers, spaces and hyphens are allowed.';
	printErrorCloseBodyAndExit($error);
    }

    printDataTable();
} elsif ($action eq 'myforms') {
    print $h->h2('My Forms');
    printDataTable();
    closeBodyAndExit();
} elsif ($action eq 'changes') {
    print $h->h2('Recent changes');
    printDataTable();
    closeBodyAndExit();
} elsif ($action eq 'help') {
    print $h->h2('Help');
    print $h->open('div', {id => 'help'});
    print $h->div('Please consider using hotkeys to fill forms faster.');
    print $h->table({ id => 'helpTable' },[
			$h->tr([
			    $h->th('Symbol'),
			    $h->th('Hotkey(s)'),
			    $h->th('How to remember?'),
			       ]),
			$h->tr([
			    $h->td('󸣮'),
			    $h->td('('),
			    $h->td(''),
			       ]),
			$h->tr([
			    $h->td('󸣯'),
			    $h->td(')'),
			    $h->td(''),
			       ]),
			$h->tr([
			    $h->td('󸣭'),
			    $h->td('m, M'),
			    $h->td(''),
			       ]),
			$h->tr([
			    $h->td('󸣥'),
			    $h->td('r'),
			    $h->td('rotation'),
			       ]),
			$h->tr([
			    $h->td('󸣘'),
			    $h->td('R'),
			    $h->td(''),
			       ]),
			$h->tr([
			    $h->td('󸣱'),
			    $h->td('s'),
			    $h->td(''),
			       ]),
			$h->tr([
			    $h->td('󸣬'),
			    $h->td('S'),
			    $h->td(''),
			       ]),
			$h->tr([
			    $h->td('󸣕'),
			    $h->td('t'),
			    $h->td('throw'),
			       ]),
			$h->tr([
			    $h->td('󸣖'),
			    $h->td('c'),
			    $h->td('catch'),
			       ]),
			$h->tr([
			    $h->td('󸣇'),
			    $h->td('!'),
			    $h->td(''),
			       ]),
			$h->tr([
			    $h->td('󸣆'),
			    $h->td('v'),
			    $h->td(''),
			       ]),
			$h->tr([
			    $h->td('󸣡'),
			    $h->td('V'),
			    $h->td(''),
			       ]),
			$h->tr([
			    $h->td('󸣫'),
			    $h->td('w, W'),
			    $h->td('walkover'),
			       ]),
			$h->tr([
			    $h->td('󸣈'),
			    $h->td('x, X'),
			    $h->td(''),
			       ]),
			$h->tr([
			    $h->td('󸣔'),
			    $h->td('b, B'),
			    $h->td('boomerang'),
			       ]),
			$h->tr([
			    $h->td('󶇋'),
			    $h->td('f'),
			    $h->td('fouette'),
			       ]),
			$h->tr([
			    $h->td('󶇌'),
			    $h->td('F'),
			    $h->td('fouette'),
			       ]),
			$h->tr([
			    $h->td('󸣶'),
			    $h->td('1'),
			    $h->td(''),
			       ]),
			$h->tr([
			    $h->td('󸣷'),
			    $h->td('2'),
			    $h->td(''),
			       ]),
			$h->tr([
			    $h->td('󸣸'),
			    $h->td('3'),
			    $h->td(''),
			       ]),
			$h->tr([
			    $h->td('󸣹'),
			    $h->td('4'),
			    $h->td(''),
			       ]),
			$h->tr([
			    $h->td('󸣺'),
			    $h->td('5'),
			    $h->td(''),
			       ]),
			$h->tr([
			    $h->td('󸣻'),
			    $h->td('6'),
			    $h->td(''),
			       ]),
			$h->tr([
			    $h->td('󸣼'),
			    $h->td('7'),
			    $h->td(''),
			       ]),
			$h->tr([
			    $h->td('󸣀'),
			    $h->td('8'),
			    $h->td(''),
			       ]),
			$h->tr([
			    $h->td('󸢼'),
			    $h->td('*'),
			    $h->td(''),
			       ]),
			$h->tr([
			    $h->td('󸣜'),
			    $h->td('z, Z'),
			    $h->td(''),
			       ]),
			$h->tr([
			    $h->td('󸣛'),
			    $h->td('#'),
			    $h->td(''),
			       ]),
			$h->tr([
			    $h->td('󸣣'),
			    $h->td('Q'),
			    $h->td(''),
			       ]),
			$h->tr([
			    $h->td('󸣙'),
			    $h->td('o'),
			    $h->td(''),
			       ]),
			$h->tr([
			    $h->td('󸣚'),
			    $h->td('O'),
			    $h->td(''),
			       ]),
			$h->tr([
			    $h->td('󸢾'),
			    $h->td('0'),
			    $h->td(''),
			       ]),
			$h->tr([
			    $h->td('󸣄'),
			    $h->td('-'),
			    $h->td(''),
			       ]),
			$h->tr([
			    $h->td('󸣃'),
			    $h->td('|, l'),
			    $h->td(''),
			       ]),
			$h->tr([
			    $h->td('󸣝'),
			    $h->td('/'),
			    $h->td(''),
			       ]),
			$h->tr([
			    $h->td('󸢸'),
			    $h->td('>'),
			    $h->td(''),
			       ]),
			$h->tr([
			    $h->td('󸢿'),
			    $h->td('_'),
			    $h->td(''),
			       ]),
			$h->tr([
			    $h->td('󸣋'),
			    $h->td('&lt;'),
			    $h->td(''),
			       ]),
			$h->tr([
			    $h->td('󸣊'),
			    $h->td('L'),
			    $h->td(''),
			       ]),
			$h->tr([
			    $h->td('󸣉'),
			    $h->td('@'),
			    $h->td(''),
			       ]),
			$h->tr([
			    $h->td('󳬃' . $h->span({class => 'elementDescription'},'(on flat foot)')),
			    $h->td('.'),
			    $h->td(''),
			       ]),
			$h->tr([
			    $h->td('󸣗'),
			    $h->td('^'),
			    $h->td(''),
			       ]),
			$h->tr([
			    $h->td('󸣵'),
			    $h->td('+'),
			    $h->td(''),
			       ]),

			$h->tr([
			    $h->td('󸣂'),
			    $h->td('h'),
			    $h->td(''),
			       ]),
			$h->tr([
			    $h->td('󸣁'),
			    $h->td('H'),
			    $h->td(''),
			       ]),
			$h->tr([
			    $h->td('󸣐'),
			    $h->td('i'),
			    $h->td(''),
			       ]),
			$h->tr([
			    $h->td('󸣑'),
			    $h->td('I'),
			    $h->td(''),
			       ]),
			$h->tr([
			    $h->td('󸢹'),
			    $h->td('j'),
			    $h->td(''),
			       ]),
			$h->tr([
			    $h->td('󸣒'),
			    $h->td('J'),
			    $h->td(''),
			       ]),
			$h->tr([
			    $h->td('󶆲'),
			    $h->td('a'),
			    $h->td('attitude'),
			       ]),
			$h->tr([
			    $h->td('󳪬'),
			    $h->td('A'),
			    $h->td('attitude'),
			       ]),
			$h->tr([
			    $h->td('󳫥'),
			    $h->td('T'),
			    $h->td(''),
			       ]),
			$h->tr([
			    $h->td('󱏻'),
			    $h->td('%'),
			    $h->td(''),
			       ]),
		    ]);
    print $h->close('div');
    closeBodyAndExit();
} elsif ($action eq 'donate') {
    print $h->h2('Donate');
    print $h->open('div', {id => 'donate'});
    print $h->div('The aim of the project is to make the process of filling RG difficulty forms faster and more convenient.');
    print $h->div('As a former coach and judge I realize the need for a proper software.');
    print $h->div('This website will always be available free of charge.');
    print $h->div('You can support me by making a donation if you want.');
    print $h->close('div');
    closeBodyAndExit();
} elsif ($action eq 'comments') {
    print $h->h2('Recent Comments');
    getLatestComments();
    closeBodyAndExit();
} elsif ($action eq 'search') {
    printSearchForm();
    closeBodyAndExit();
} elsif ($action eq 'contact') {
    print $h->h2('Contact me');
    print $h->div({id => 'contact'},'marjana.voronina+rg@gmail.com');
    closeBodyAndExit();
}

if ($action eq 'clone') {
    $formId = undef;
}

if ($comment ne '') {

    if ($ENV{'REQUEST_METHOD'} eq 'POST') {
	lockOperation();

	unless (-d $formCommentsFolder) {
	    mkdir ($formCommentsFolder);
	}

	my ($ok, $storedIn) = readFile($formCommentsFile);
	if (not $ok) {
	    # TODO
	}

	my $dateTime = DateTime->from_epoch(epoch => time, time_zone => 'UTC');
	my $date = $dateTime->date;
	my $time = $dateTime->time;

	if ($storedIn) {
	    $storedIn = $coder->decode($storedIn);
	    @comments =  @{$storedIn};
	}

	my %newCommentData = (
	    commenter => $commenter || 'Anonymous',
	    comment  => $comment,
	    date => $date,
	    time => $time,
	    commenterIP => $commenterIP,
	    );

	push @comments, \%newCommentData;

	my $storedOut = $coder->encode(\@comments);

	writeStringToFile($formCommentsFile, $storedOut);
	unlockOperation();
    }
}


printFormId();

if ($formId ne '' and $action eq '') {
    my $numberOfComments = countComments($formId);
    print $h->div({ id => 'numberOfComments'}, $h->a({href => '#comments'}, "($numberOfComments)"));
}

if ($formId ne '') {
    if ( canEdit() ) {
	print $h->div({class => 'author'}, 'You can edit this form.');
	$disableInputsStatus = 'inputsEnabled';

    } else {
	print $h->div({class => 'notAuthor'}, 'You can\'t edit this form');
	$disableInputsStatus = 'inputsDisabled';
    }
}
printAllInputsForm();

if ($formId ne '') {
    print $h->open('div', {id => 'comments', class => 'centered'});
    printAllComments();
    print $h->open('form', { action => '', method => 'POST', id => 'addComment'});
    print $h->h2('Leave a comment');
    print $h->span('Your name:');
    print $h->closed( 'input', { type => 'text', name => 'commenter', id => 'commenter', value => getCommenterName(), maxlength => '30', required => 'required'});
    print $h->span('Your comment:');
    #TODO captcha
    print $h->textarea({ name => 'commentForm', id => 'commentForm', maxlength => '2000', required => 'required'});
    print $h->input({ name => 'id', hidden => 'hidden', value => $formId});
    print $h->button({id => 'publishBtn', class => '', accesskey => 'c'}, 'COMMENT');
    print $h->close('form');
    print $h->close('div');
}
print $h->open('div', {id => 'id01'}, {class => 'w3-modal'});
print $h->open('div', {class => 'w3-modal-content'});
print $h->open('div', {class => 'w3-container'});
print $h->open('div', {class => 'tabs'});
print $h->open('div', {id => 'tabsNav'});
print $h->span({id => 'closeBtn', class => 'w3-closebtn'}, 'x');
print $h->ul({class => 'tab-links'}, [
		 $h->li({class => 'active'}, $h->a({href => '#tab1'},'Jumps')),
		 $h->li($h->a({href => '#tab2'},'Balances')),
		 $h->li($h->a({href => '#tab3'},'Rotations')),
		 $h->li($h->a({href => '#tab4'},'DER/Mastery/Other')),
		 $h->li($h->a({href => '#tab5'},'Apparatus')),
		 $h->li($h->a({href => '#tab6'},'All symbols'))

	     ]);
print $h->open('div', {id => 'addElements'});
print $h->span('Symbols to insert: ');
print $h->input({id => 'elementsToInsert', name => 'elementsToInsert'});
print $h->open('div', {class => 'modalButtons'});
print $h->span({class=>'w3-btn'},{id=>"insertButton"},'OK (Enter)');
print $h->span({class=>'w3-btn'},{id=>'clearButton'},'Clear');
print $h->close('div');
print $h->close('div');
print $h->close('div');

print $h->open('div', {class => 'tab-content'});

my $balances = $difficulties{'balances'};
my $jumps = $difficulties{'jumps'};
my $rotations = $difficulties{'rotations'};

my %jumpsTab = (
    "id"  => "tab1",
    "class" => "tab active",
    "elements" => $jumps,
    );

my %balancesTab = (
    "id"  => "tab2",
    "class" => "tab",
    "elements" => $balances,
    );

my %rotationsTab = (
    "id"  => "tab3",
    "class" => "tab",
    "elements" => $rotations,
    );
my %otherTab = (
    "id"  => "tab4",
    "class" => "tab",
    "elements" => @other,
    );
my %apparatusTab = (
    "id"  => "tab5",
    "class" => "tab",
    "elements" => @apparatus,
    );

my %allSymbolsTab = (
    "id"  => "tab6",
    "class" => "tab",
    "elements" => @allElements,
    );

my @elementsValues = ('', '0.1', '0.2', '0.3', '0.4', '0.5');
my @apparatusGroups = ('', 'Fundamental', 'Other');

generateBodyDifficultyTabs(\%jumpsTab, \%balancesTab, \%rotationsTab);
generateOtherTab(\%otherTab);
generateApparatusTab(\%apparatusTab);
generateOtherTab(\%allSymbolsTab);


print $h->close('div');
print $h->close('div');
print $h->close('div');
print $h->close('div');
print $h->close('div');
print $h->close('body');
print $h->close('html');


if (getParam('pdf')) {
    select STDOUT;
    binmode(STDOUT, ':raw');
    close $TEMP;
    (undef, my $tempPdf) = tempfile(OPEN => 0, DIR => $tmpFolder);
    system('wkhtmltopdf', '-q', '--print-media-type', '-L', '10mm', '-R', '10mm', '-T', '12.5mm', '--encoding', 'UTF-8', $tempFile, $tempPdf);
    open (my $pdf, '<', $tempPdf);
    binmode($pdf);
    while (<$pdf>) {
	print $_;
    }
}

sub generateElementsTableHead {
    my ($thead) = @_;
    print $h->open('table', {class => 'elementsTable'});
    print $h->open('tr',{ class => 'centered' });

    foreach (@$thead) {
	print $h->open('th');
	print $_;
	print $h->close('th');
    }
    print $h->close('tr');
}

sub generateElementsTable {
    my ($elements) = @_;

    foreach my $row (@$elements) {
	print $h->open('tr');
	my $cnt;
	foreach my $elementTd (@$row) {
	    print $h->open('td');

	    foreach my $element (@$elementTd) {
		unless ($cnt++) {
		    print $h->span({class=>"elementGroupDescription"}, "$element");
		    next;
		}
		print $h->span({class=>"elementsInFIGTable"}, "$element");
	    }
	    print $h->close('td');
	}
	print $h->close('tr');
    }
    print $h->close('table');
}


sub generateBodyDifficultyTabs {
    my @tabs = @_;
    foreach (@tabs) {
	print $h->open('div', {id => "$_->{id}"},{class => "$_->{class}"});
	generateElementsTableHead(\@elementsValues);
	generateElementsTable($_->{elements});
	print $h->close('div');
    }
}

sub generateApparatusTab {
    my @tab = @_;
    foreach (@tab) {
	print $h->open('div', {id => "$_->{id}"},{class => "$_->{class}"});
	generateElementsTableHead(\@apparatusGroups);
	generateElementsTable($_->{elements});
	print $h->close('div');
    }
}

sub generateTabWithNoTable {
    my @tabs = @_;
    foreach (@tabs) {
	print $h->open('div', {id => "$_->{id}"},{class => "$_->{class}"});
	generateElementsWithNoTable($_->{elements});
	print $h->close('div');
    }
}

sub generateOtherTab {
    my @tabs = @_;
    my $headingNr = 0;
    foreach (@tabs) {
	print $h->open('div', {id => "$_->{id}"},{class => "$_->{class}"});
	my @otherElements =  $_->{elements};
	foreach my $x (@otherElements) {
	    foreach my $y (@$x) {
		print $h->open('div', {class => 'blockOfOtherElements'});
		foreach (@$y) {
		    print $h->span({class=>"elementsInFIGTable"}, "$_");
		}
		print $h->close('div');

	    }
	}	print $h->close('div');
    }
}

sub generateElementsWithNoTable {
    my ($elements) = @_;
    foreach (@$elements) {
	print $h->span({class=>"elementsInFIGTable"}, "$_");
    }
}


sub generateTableBlock {
    my @params = @_;
    my $cellId = $params[0];
    my $tabIndex = $cellId;
    my $elementValueKey = "value$cellId";
    my $symbolsKey = "symbolsInForm$cellId";
    return $h->td(
	$h->table({id => $cellId}, {class => 'mainFormTableCell'},
		  [$h->tr({ class => 'valueRow'},[$h->td('Value'), $h->td($h->input({class => 'valueInput',
										     name => "value$cellId",
										     value => ($formData{$elementValueKey} // ''),
										     tabindex => $tabIndex})),
						  $h->td({rowspan => 2, class =>'editBtn'},

							 [
							  $h->div({class => 'plus'}, '＋'),
							  $h->div({class => 'valueWarning'}, 'Please use format 0.3 or 0.1+0.2=0.3'),
							 ]

						  )]),
		   $h->tr({class => 'symbolsRow'},[$h->td({colspan => 2}, $h->input({class => 'symbolsInForm',
										     name => "symbolsInForm$cellId",
										     value => ($formData{$symbolsKey} // ''),
										     tabindex => $tabIndex}))])
		  ]));
}

sub printRoutineLogo {
    my $logosFolder = '../img/routines';

    my @logos = qw(freehands rope hoop ball clubs ribbon);
    my $allRoutinesLogos = '';
    foreach (@logos) {
	my $isChecked =  ($formData{'apparatus'} // '') eq $_ ? 'checked' : 'unchecked';

	$allRoutinesLogos .= $h->input({type => 'radio', class => "apparatus $isChecked", name => 'apparatus', value => $_, id => "$_"});
	$allRoutinesLogos .= $h->label({for => "$_", title => $_}, $logos{$_});
    }
    return $allRoutinesLogos;
}

sub getParam {
    my ($param) = @_;
    my $result = $q->param($param);
    return '' unless defined $result; # TODO undefs are ok too
    utf8::decode($result);
    $result = escapeHTML($result);
    $result =~ s/^\s+|\s+$//g; # trim
    $result =~ s/\s+/ /g; # multiple spaces

    if ($param  eq 'formId' ||$param  eq 'id' ) {
	$result =~ s!/!!g; # remove slashes
	$result =~ s/\.//g; # remove dots
    }
    return $result;
}

sub readFile {
    my ($file) = @_;
    utf8::encode($file); # filenames are bytes!
    if (open(my $IN, '<:encoding(UTF-8)', $file)) {
	local $/ = undef; # Read complete files
	my $data = <$IN>;
	close $IN;
	return (1, $data);
    }
    return (0, '');
}

sub printSearchForm {
    print $h->h2('Search');
    print $h->open('div',{id => 'search'});
    print $h->open('form');
    print $h->div('Please enter a gymnast\'s name or form id');
    print $h->input({name => 'query', value => "$query", maxlength => '64', required => 'required'});
    print $h->button({id => 'searchBtn'}, 'SEARCH');
    print $h->close('form');
    print $h->close('div');
}

sub getAllForms {
    my ($fileToGet) = @_;
    opendir (my $DIR, $formsFolder) or die $!;
    my @allFormsFolders;

    my @files = readdir($DIR);

    my @filesSortedByDate = sort { -M "$formsFolder/$a" <=> -M "$formsFolder/$b" } (@files);

    foreach my $file (@filesSortedByDate) {

        # Use a regular expression to ignore files beginning with a period
        next if ($file =~ m/^\./);
	push @allFormsFolders, $file;
    }
    closedir($DIR);

    my @allForms;

    foreach my $formFolder (@allFormsFolders) {
	$formFolder = "$formsFolder/$formFolder";
	opendir (DIR, $formFolder) or die $!;


	while (my $file = readdir(DIR)) {
	    if ($file eq "$fileToGet.json") {
		push @allForms, "$formFolder/$file";
	    }
	}
	closedir(DIR);

    }
    return @allForms;
}

sub canEdit {
    my ($formIdParam) = @_;
    if (($formIdParam // '') ne '') { $formId = $formIdParam; }

    if ( exists $cookies{$formId} ) {
	if ($cookies{$formId}->name eq sha256_hex($cookies{$formId}->value)) {
	    return 1;
	}
    } else {
	return 0;
    }
}

sub writeStringToFile {
    my ($file, $string) = @_;
    utf8::encode($file);
    unless (-d $tmpFolder) {mkdir $tmpFolder;}
    ($TEMP, $tempFile) = tempfile(DIR => $tmpFolder);
    chmod(0660, $tempFile);
    binmode($TEMP, ':encoding(UTF-8)');
    print $TEMP $string;
    close($TEMP);
    mv($tempFile, $file) or die "Move failed: $!";
}

sub lockOperation {
    while (!mkdir($lock, 0644)) {
	my $mtime = (stat $lock)[9]; # time created in seconds
	if (-d $lock and time() - $mtime  > 10) {
	    unlockOperation();
	    next;
	}
	sleep(0.3);
    }
    return;
}

sub unlockOperation {
    rmdir($lock);
    return;
}

sub printAllComments {

    if (-s $formCommentsFile) {
	print $h->h2('Comments');
	#TODO create a function
	my ($ok, $storedIn) = readFile($formCommentsFile);
	if (not $ok) {
	    # TODO
	}
	if ($storedIn) {
	    $storedIn = $coder->decode($storedIn);
	    @comments =  @{$storedIn};
	}

	for my $comment (@comments) {
	    my $time = $comment->{time};
	    $time =~ s/://g;
	    print $h->div({class => 'comment', id => "comment$comment->{date}_$time"},[
			      $h->div({class => 'commenterAndDate'}, $h->span($comment->{commenter}) . ' commented on '
				      . $h->a({class => 'date', href => "#comment$comment->{date}_$time"},
					      "$comment->{date} $comment->{time} UTC")),
			      $h->div({class => 'commentText'}, $comment->{comment}),
			  ]);
	}

    }
}

sub printFormId {
    my $formIdClass = '';
    if ($formId) {
	print $h->h2({id => 'formIdHeading', class => "$formIdClass"}, "Form id: " . $h->a({class => 'link', href => "/$formId" }, $formId));
    } else {
	print $h->h2({id => 'formIdHeading', class => "$formIdClass"},"Unsaved form");
    }
}

sub printAllInputsForm {
    print $h->open('div',{id => 'allInputs', class => "$disableInputsStatus"});
    if ( canEdit() || $formId eq '') {
	print $h->open('div', {id => 'msgFromServer'});
	print $h->close('div');
	print $h->open('div', {id => 'saveOptions'});

	if (($formData{'hideName'} // '') eq 'on') {
	    $hiddenName = 'checked';
	}
	print $h->closed( 'input', { type => 'checkbox', name => 'hideName', id => 'hideName', class => $hiddenName, tabindex => 1 });
	print $h->label({for => 'hideName'},'Hide gymnast\'s name before publishing');
	print $h->div({id => 'attention'},'NB! You won\'t be able to find this form by gymnast\'s name later! Please make sure you save the id of the form if you choose this option.');
	print $h->close('div');
    }

    print $h->open('div', {id => 'magicButtons'});
    if ( canEdit() || $formId eq '') {
	print $h->button({id => 'saveBtn', class => '', accesskey => 's'}, 'SAVE');
        ## TODO!!!
       ##print $h->button({id => 'cloneBtn', class => ''}, 'CLONE');
    } else {
	print $h->button({id => 'cloneBtn', class => ''}, 'CLONE');
    }
    print $h->button({id => 'pdfBtn', class => 'button'}, 'PDF');
    print $h->close('div');
    print $h->div({id => 'saveStatus'}, 'Saved.');
    print $h->table({ id=>'mainForm'}, $tablecontent);
    print $h->open('div', {id => 'signatures'});
    print $h->div({class => 'signature'},'Coach Signature .........................');
    print $h->div({class => 'signature'},'Judge Signature .........................');
    print $h->close('div');
    print $h->close('div'); #allInputs
}

sub getFormId {
    if ($action eq 'clone') {
	return $formId = '';
    }
    return $formData{'formId'} || $formId;
}

sub getCommenterName {
    if ($commenter) {return $commenter;}
    if (exists ($cookies{'commenter'})) {return $cookies{'commenter'}->value};
    return 'Anonymous';
}

sub getLatestComments {
    my @comments = getAllForms('comments');
    my @searchResults;
    my $rowColor = '';

    foreach my $commentFile (@comments) {
	my @formPath = split("/", dirname($commentFile));
	my $formId = $formPath[-1];
	if ( canEdit($formId)) {
	    $rowColor = 'greenRow';
	} else {
	    $rowColor = 'whiteRow';
	}

	my ($ok, $storedIn) = readFile($commentFile);
	if (not $ok) { # TODO
	    1;
	}

	my @commentData = @{$coder->decode($storedIn)};

	my $hash_ref = $commentData[-1];
	my %hash = %$hash_ref;
	my $dateAndTime =  $hash{'date'} . " " . $hash{'time'};
	my $commenter =  $hash{'commenter'};
	my $comment = $hash{'comment'};
	if (length($comment) > 100) {
	    $comment = substr($comment, 0, 100) . '...';
	}

	push @searchResults, $h->tr({ class => $rowColor},[
					$h->td($dateAndTime),
					$h->td($commenter),
					$h->td($comment),
					$h->td($h->a({href=>"/$formId#comments", class => 'button viewBtn'}, 'View')),
				    ]);
    }

    if (@searchResults > 0) {
	print $h->open('table', {id => 'recentComments'});
	print $h->tr([
	    $h->th('Date and Time (UTC)'),
	    $h->th('Commenter'),
	    $h->th('Comment'),
	    $h->th('Action'),

		     ]);
	foreach (@searchResults) {
	    print $_;
	}
	print $h->close('table');
    } else {
	print $h->div({class => 'centered'},'Nothing was found.');
    }
}

sub countComments {
    my ($formId) = @_;

    my $formCommentsFolder = "$formsFolder/$formId";

    my $formCommentsFile = "$formCommentsFolder/comments.json";

    my $textToPrint = '';

    if (-s $formCommentsFile) {
	#TODO create a function
	my ($ok, $storedIn) = readFile($formCommentsFile);
	if (not $ok) {
	    # TODO
	}
	if ($storedIn) {
	    $storedIn = $coder->decode($storedIn);
	    @comments =  @{$storedIn};
	}
	my $numberOfComments = scalar @comments;
	if ($numberOfComments == 1) { $textToPrint = '1&nbsp;comment'; }
	else { $textToPrint = "$numberOfComments&nbsp;comments"; }
    } else {
	$textToPrint = '0&nbsp;comments';
    }
    return "$textToPrint";
}

sub getNameOrLink {
    my @params = @_;
    my $hidden = $params[0];
    my $name = $params[1];
    if(($hidden // '') eq 'on' || $name eq '') { return $name; }
    return $h->a({href => "../?query=$name"}, $name);
}

sub printErrorCloseBodyAndExit {
    my ($error) = @_;
    print $h->div({class => 'centered error'}, $error);
    closeBodyAndExit();
}

sub getHashFromFile {
    my ($file) = @_;
    my ($ok, $storedIn) = readFile($file);
    if (not $ok) { # TODO
	1;
    }
    return  %{$coder->decode($storedIn)};
}

sub printDataTable {
    my @forms = getAllForms('form');

    foreach my $form (@forms) {

	my @formPath = split("/", dirname($form));
	my $formId = $formPath[-1];

	%formData =  getHashFromFile($form);

	my $gymnastsName = lc $formData{'gymnastsName'};
	my $NF = $formData{'NF'};
	my $apparatus = $formData{'apparatus'};
	my $gymnastsNameHidden = $formData{'hideName'};
	my $rowColor = '';
	my $editable = '';
	if (($gymnastsNameHidden // '') eq 'on' && $action ne 'myforms') {$gymnastsName = $secretName;}

	if ( canEdit($formId)) {
	    $rowColor = 'greenRow';
	    $editable = 'YES';
	} else {
	    if ($action eq 'myforms') { next; }
	    $rowColor = 'whiteRow';
	    $editable = 'NO';
	}
	my $formModificationTime = stat($form)->mtime();

	if ($query ne '') {
	    if ($gymnastsName !~ /$lcQuery/ && $formId !~/^$lcQuery$/) {
		next;
	    }
	    if (($gymnastsNameHidden // '') eq 'on' && $formId !~/^$lcQuery$/) { next; }
	}

	my $gymnastsNameUC = uc $gymnastsName;
	push @searchResults, $h->tr({class => $rowColor},[
					$h->td(strftime("\%Y-\%m\-%d\ %H:\%M:\%S", gmtime($formModificationTime))),
					$h->td(getNameOrLink($gymnastsNameHidden, $gymnastsNameUC)),
					$h->td(uc $NF),
					$h->td({class => 'recentChangesApparatusIcon', title => $formData{'apparatus'}},
					       exists $logos{$formData{'apparatus'}} ? $logos{$formData{'apparatus'}} : $formData{'apparatus'}),
					$h->td($editable),
					$h->td($h->a({href => "/$formId#comments"}, countComments($formId))),
					$h->td($h->a({href => "/$formId", class => 'button viewBtn'}, 'View')),
				    ]);
    }
    if (@searchResults > 0) {
	print $h->open('table', {id => 'searchResults'});
	print $h->tr([
	    $h->th('Time modified (UTC)'),
	    $h->th('Gymnast\'s name'),
	    $h->th('NF'),
	    $h->th('Apparatus'),
	    $h->th('Can I edit this form?'),
	    $h->th('Comments'),
	    $h->th('Action'),
		     ]);
	foreach (@searchResults) {
	    print $_;
	}
	print $h->close('table');
    } else {
	print $h->div({class => 'centered'},'Nothing was found.');
	if ($action eq 'myforms') {
	    print $h->div({class => 'centered'},'Start ' . $h->a({href => '/', class => 'link'}, 'filling a form') . ' right now!');
	}
    }
    closeBodyAndExit();
}

sub showNameInTitle {
    unless (($formData{'hideName'} // '') eq 'on') {
	my $newTitle = $formData{'gymnastsName'};
	if (defined $newTitle and $newTitle ne '') {
	    if (defined $formData{'apparatus'}) {
		$newTitle .= " $formData{'apparatus'}";
	    }
	    return uc $newTitle;
	}
    }
    return undef;
}

sub closeBodyAndExit {
    print $h->close('body');
    print $h->close('html');
    exit 0;
}
