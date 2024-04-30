"use strict";

var editButton = '';
var closestInput = '';
var elements = '';
var clickedLogo = '';

// "v":"󸣆",
// "V":"󸣡",


var shortcut = {
    "1":"󸣶",
    "2":"󸣷",
    "3":"󸣸",
    "4":"󸣹",
    "5":"󸣺",
    "6":"󸣻",
    "7":"󸣼",
    "8":"󸣀",
    "∞":"󸣀",
    "*":"󸢼",
    "9":"󸣾",
    "R":"󸣘",
    "r":"󸣥",
    "M":"󸣭",
    "m":"󸣭",
    "S":"󸣬",
    "s":"󸣱",
    "(":"󸣮",
    ")":"󸣯",
    "+":"󸣵",
    "O":"󸣚",
    "o":"󸣙",
    "Z":"󸣜",
    "z":"󸣜",
    "#":"󸣛",
    "e":"󸢺",
    "E":"󸢻",
    "-":"󸣄",
    "_":"󸢿",
    "<":"󸣋",
    "L":"󸣊",
    "@":"󸣉",
    ".":"󳬃",
    "/":"󸣝",
    "|":"󸣃",
    "l":"󸣃",
    "t":"󸣕",
    "↗":"󸣕",
    "↑":"󸣕",
    "c":"󸣖",
    "↓":"󸣖",
    "!":"󸣇",
    "X":"󸣈",
    "x":"󸣈",
    "w":"󸣫",
    "W":"󸣫",
    "Q":"󸣣",

    "b":"󸣔",
    "B":"󸣔",

    "f":"󶇋",
    "F":"󶇌",

    "^":"󸣗",
    "0":"󸢾",
    ">":"󸢸",

    "h":"󸣂",
    "H":"󸣁",
    "i":"󸣐",
    "I":"󸣑",
    "j":"󸢹",
    "J":"󸣒",

    "a":"󶆲",
    "A":"󳪬",
    "T":"󳫥",
    "%":"󱏻",
};

var fundamental = new Object();
fundamental["rope"] = ["󸢸","󸢹","󸢺","󸢻","󸢼","󸢽","󸣪"];
fundamental["hoop"] = ["󸢸","󸣁","󸣂","󸢾","󸣃","󸣄","󸣢","󸣣","󸣧","󸣨","󸣩","󸣪"];
fundamental["ball" ] = ["󸣁","󸣂","󸣆","󸢼","󸣇","󸣢","󸣧","󸣨","󸣩"];
fundamental["clubs"] = ["󸣈","󸣉","󸣊","󸣋","󸣧","󸣨"];
fundamental["ribbon"] = ["󸣐","󸣑","󸢹","󸣒","󸣓","󸢺","󸣧","󸣨"];

var other = new Object();
other["rope"] = ["󸢾","󸢿","󸣀"];
other["hoop"] = ["󸣅","󸢿"];
other["ball"] = ["󸣀","󸢿"];
other["clubs"] = ["󸢾","󸣀","󸢿","󸣌","󸣍","󸣎","󸣏"];
other["ribbon"] = ["󸣔","󸣀","󸢿"];
other["allApparatus"] = ["󸣕","󸣖","󸣀","󸣗"];

var inputValueRegex1 = /^\d\.\d$/;
var inputValueRegex2 = /^(\d\.\d\+)+\d\.\d=\d\.\d$/;
var inputToCount = /^(\d\.\d\+)+\d\.\d$/;

//TODO find another solution

RegExp.escape= function(s) {
    return s.replace(/[-\/\\^$*+?.()|[\]{}]/g, '\\$&');
};

function saveForm(pdf) {
    var allInputs = $('#allInputs').find('input, select, radio').serialize();
    // var id = $( "input[name='formId']" ).val();
    // window.location.href = "../" + id + "?pdf=1" ;
    $.ajax({
	method: "POST",
	url: "../cgi-bin/save.pl",
	data: allInputs,
	success: function(msg){
	    var formLink = window.location.origin +'?id=' + msg;
	    // $("#msgFromServer").html("Please save this link if you want to be able to edit this form in the future: <a href=" + formLink + ">" + formLink+ "</a>");
	    $('#formIdHeading').css("visibility","visible");
	    if (msg.indexOf('Error') == -1 && msg.indexOf('error') == -1) {
		$('#formIdHeading').css("color","#0d0d0d");
		$('#formId').val(msg);
		$('#formIdHeading').html("Form id: " + "<a class='link' href=../" + msg + ">" + msg + "</a>");
		$('#saveStatus').css({"visibility":"visible", "opacity":"1"});
		window.history.pushState("string", "Title", "../" + msg);

		if (pdf == 1) {

		    var id = $( "input[name='formId']" ).val();
		    window.location.href = "../" + id + "?pdf=1" ;

		}

	    } else {
		$('#formIdHeading').css("color","#e60000");
		$('#formIdHeading').html(msg);
	    }
	},
	error: function(XMLHttpRequest, textStatus, errorThrown) {
	}
    });
}

function countTotalValue(totalValue) {
    if (isNaN(totalValue)) {
	$(".totalInput").val('0.0');
    } else { $(".totalInput").val(totalValue.toFixed(1)); }
}

function checkValueInputs(thisObj) {
    if (!inputValueRegex1.test(thisObj.val()) && !inputValueRegex2.test(thisObj.val())) {
	thisObj.css("border","1px solid red");
    } else { thisObj.css("border","1px solid #03899C"); }
}

function cropBeforeEqualSign(curValue) {
    if (curValue.indexOf('=') > -1) {
	var n = curValue.indexOf("=");
	curValue = curValue.substr(0, n);
    } return curValue;
}

function insertSymbolToInput(symbol) {
    var input = document.getElementById("elementsToInsert");
    var symbol = symbol.textContent;
    var val = input.value;
    var start = input.selectionStart, end = input.selectionEnd;
    input.value = val.slice(0, start) + symbol + val.slice(end);
    input.focus();
    var caretPos = start + symbol.length;
    input.setSelectionRange(caretPos, caretPos);
}

function clearInput() {
    var input = document.getElementById('elementsToInsert');
    input.value = '';
    $("#elementsToInsert").focus();
}

function closeModalWindow() {
    $( "#id01" ).css( "display", "none" );
    // $("body").css("overflow-y", "visible");
    $("#mainForm").css("margin-bottom", "50px");
}

function replaceSpecialSymbols(thisObj) {
    var value = thisObj.val();
    var oldValue = value;
    for (var i in shortcut) {
	var regex = new RegExp(RegExp.escape(i), "g");
	value = value.replace(regex, shortcut[i]);
    }
    thisObj.val(value);
    if (value == oldValue)
	return -1;
    return value.length - oldValue.length;
}

function countFundamentals() {
    var fundamentalElements = 0;
    var otherElements = 0;
    var selectedRoutine = $('input[type="radio"]:checked').val();
    if (selectedRoutine == 'freehands') {
	$("#fundamentalElements").val("-");
	$("#otherElements").val("-");
	$("#fundamentalsPercent").hide();
	return;
    }

    $("#fundamentalsPercent").show();

    var curApparatus = selectedRoutine;

    $('.symbolsInForm').each(function() {

	var curSymbols = ($(this).val());
	curSymbols = punycode.ucs2.decode(curSymbols);
	var curSymbolsLength = curSymbols.length;

	for (var i = 0; i < curSymbolsLength; i++) {
	    var eightSign = false;

	    for (var j = 0; j < fundamental[curApparatus].length; j++) {
		var curFundamentalElelement =  punycode.ucs2.decode(fundamental[curApparatus][j]);
		if (curSymbols[i] == curFundamentalElelement) {
		    fundamentalElements++;
		}
	    }
	    for (var j = 0; j < other[curApparatus].length; j++) {
		var curOtherElement = punycode.ucs2.decode(other[curApparatus][j]);
		if (curSymbols[i] == curOtherElement) {
		    if(curSymbols[i] == punycode.ucs2.decode('󸣀')) { eightSign = true;}
		    otherElements++;
		}
	    }
	    for (var j = 0; j < other["allApparatus"].length; j++) {
		var curOtherElement = punycode.ucs2.decode(other["allApparatus"][j]);
		if (curSymbols[i] == curOtherElement) {
		    if (eightSign == true) {continue;}
		    otherElements++;
		}
	    }
	}
    });

    $("#fundamentalElements").val(fundamentalElements);
    $("#otherElements").val(otherElements);

    if (otherElements > 0) {
	var percentOfFundamentalElements = fundamentalElements/(fundamentalElements + otherElements) *100;
	$("#fundamentalsPercent").text('(' + Number(percentOfFundamentalElements.toFixed(1)) + '%)');
	if (percentOfFundamentalElements < 50) {
	    $("#fundamentalsPercent").css("color","#e60000");
	} else { $("#fundamentalsPercent").css("color","black"); }
    } else {
	$("#fundamentalsPercent").text('(0%)');
    }
}

$(document).ready(function(){

    var totalValue = $(".totalInput").val();
    totalValue  = parseFloat(totalValue);
    countTotalValue(totalValue);

    $( ".valueInput" ).each(function() {
	if ( $(this).val()) { checkValueInputs( $(this) ); }
    });

    $( ".valueInput" ).hover(
	function() {
	    $(this).parent("td").next("td").find(".valueWarning").show();
	}, function() { $(this).parent("td").next("td").find(".valueWarning").hide(); }
    );

    $("input[type=radio]").change(function(){
	countFundamentals();
    });

    $('.tabs .tab-links a').on('click', function(e)  {
	var currentAttrValue = jQuery(this).attr('href');

	// Show/Hide Tabs
	$('.tabs ' + currentAttrValue).show().siblings().hide();

	// Change/remove current tab to active
	$(this).parent('li').addClass('active').siblings().removeClass('active');

	e.preventDefault();
	$("#elementsToInsert").focus();
    });

    $(".inputsDisabled").find("input").attr('readonly','readonly');
    $(".inputsDisabled").find(".editBtn").css('visibility','hidden');
    $(".inputsDisabled").find(".editBtn").css('pointer-events','none');
    $(".inputsDisabled").find("#apparatusChoice").css('pointer-events','none');

    $("#clearButton").click(function(event) {
	clearInput();
    });

    $(".elementsInFIGTable").click(function(event) {
	insertSymbolToInput(this);
    });

    $(".editBtn").click(function(event) {
	editButton = $(event.target);
	closestInput = editButton.closest("table").find("input[class='symbolsInForm']");
	elements = closestInput.val();
	$("#elementsToInsert").val(elements);
	document.getElementById('id01').style.display='block';
	// $("body").css("overflow-y", "hidden");
	// $("body").css("height", "100%");
	var caretPosition = $("#elementsToInsert").val().length;
	var input = document.getElementById("elementsToInsert");
	input.setSelectionRange(caretPosition, caretPosition);
	$("#elementsToInsert").focus();
    });

    $(".valueInput").click(function(event) {

    });

    function insertElementsToTheForm() {
	var elementsToInsert = $("#elementsToInsert").val();
	var caretPos = $("#elementsToInsert").getCaretPosition();
	$(closestInput).val(elementsToInsert);
	// TODO set right position
	$(closestInput).focus();
    }

    $("#insertButton").click(function(event) {
	insertElementsToTheForm();
	countFundamentals();
	closeModalWindow();
    });

    $("#pdfBtn").click(function(event) {
	saveForm(1);
    });

    $("#printBtn").click(function(event) {
	var musicWithWordsText = $("#musicWithWordsText").text();
	var musicWithWordsChoice = '';
	if ($('#musicWithWordsCheckBox').is(':checked')) {
	    musicWithWordsChoice = '<span>YES</span>';
	} else {
	    musicWithWordsChoice = '<span>NO</span>';
	}

	$(musicWithWordsChoice).insertAfter( $( "#musicWithWordsText" ) );
	$("#musicWithWordsCheckBox").css("visibility","hidden");
	$("#mainForm").css("margin-bottom","0px");
	window.print();
	$("#musicWithWordsCheckBox").css("visibility","visible");
	$('#musicWithWordsText').next('span').remove();
	$("#mainForm").css("margin-bottom","50px");
    });

    $("#closeBtn").click(function(event) {
	closeModalWindow();
    });

    $(".editBtn").hover(
	function () {
	    $(this).addClass('pointer');
	},
	function () {
	    $(this).removeClass('default');
	}
    );

    $( ".checked" ).prop("checked", true);

    $(".logos").hover(
	function () {
	    $(this).addClass('pointer');
	},
	function () {
	    $(this).removeClass('default');
	}
    );

    $("#saveBtn").click(function() {
	// alert('saved');
	$('#saveStatus').css({"opacity":"0"});
	saveForm(0);
    });

    $("#cloneBtn").click(function() {

	var id = $( "input[name='formId']" ).val();
	window.location.href = "../?action=clone&id=" + id ;
    });

    $(document).keypress(function(e) {
	if (e.keyCode == 27) {
	    closeModalWindow();
	}
	else if (e.keyCode == 13) {
	    insertElementsToTheForm();
	    countFundamentals();
	    closeModalWindow();
	}
    });

    $(document).keydown(function(e) {
	if(e.keyCode == 27) {
	    closeModalWindow();
	}
    });

    (function ($, undefined) {
	$.fn.getCaretPosition = function () {
	    var el = $(this).get(0);
	    var pos = 0;
	    if ('selectionStart' in el) {
		pos = el.selectionStart;
	    } else if ('selection' in document) {
		el.focus();
		var Sel = document.selection.createRange();
		var SelLength = document.selection.createRange().text.length;
		Sel.moveStart('character', -el.value.length);
		pos = Sel.text.length - SelLength;
	    }
	    return pos;
	}
    })(jQuery);

    $( ".valueInput" ).keyup(function(e) {
	var totalValue = 0.0;
	$( ".valueInput" ).each(function() {
	    var curValue = $(this).val();
	    if (!curValue) {
		curValue = 0.0;
		$(this).css("border","1px solid #03899C");
	    } else {
		var valueToAdd = 0.0;
		if (inputToCount.test(cropBeforeEqualSign(curValue))) {
		    if (curValue.indexOf('=') > -1) {
			var n = curValue.indexOf("=");
			curValue = curValue.substr(0,n);
		    }
		    var array = curValue.split("+");
		    var sum = 0;
		    for (var i = 0; i < array.length; i++) {
			sum += parseFloat(array[i]);
		    }
		    var caretPosition = $(this).getCaretPosition();

		    $(this).val(curValue + "=" + sum.toFixed(1));
		    this.setSelectionRange(caretPosition, caretPosition);
		}

		checkValueInputs( $(this) );

		valueToAdd = $(this).val();
		valueToAdd = valueToAdd.slice(-3);
		valueToAdd = parseFloat(valueToAdd);
		totalValue += valueToAdd;
	    }
	});
	countTotalValue(totalValue);
    });

    $( "#elementsToInsert" ).keyup(function() {

	var caretPositionInSymbolsForm = $(this).getCaretPosition();
	var shift = replaceSpecialSymbols( $(this) );
	if (shift > 0)
	    this.setSelectionRange(caretPositionInSymbolsForm + shift, caretPositionInSymbolsForm + shift);
	countFundamentals();
    });

    $( ".symbolsInForm" ).keyup(function() {

	var caretPositionInSymbolsForm = $(this).getCaretPosition();
	var shift = replaceSpecialSymbols( $(this) );
	if (shift > 0)
	    this.setSelectionRange(caretPositionInSymbolsForm + shift, caretPositionInSymbolsForm + shift);
	countFundamentals();
    });

    //set freehands routine by default if not checked
    if (!$('.apparatus').is(':checked')) {
	$("#freehands").prop("checked", true);
    }

    countFundamentals();

    var width = $(".editBtn").width();

    $(".judge").css("width", width + "px");

    if ($('#hideName').is(':checked')) {
	$('#attention').css("visibility","visible");

    }

    $('#hideName').change(function() {
	if ($(this).is(':checked')) {
	    $('#attention').css("visibility","visible");
	} else {
	    $('#attention').css("visibility","hidden");
	}
    });

    var currentApparatus = $('input[name=apparatus]:checked', '#mainForm').val();
    hideApparatusSymbols();

    $("input[name=apparatus]:radio").change(function () {

	currentApparatus = $('input[name=apparatus]:checked', '#mainForm').val();
	hideApparatusSymbols();
    });

    function hideApparatusSymbols() {
	$(".elementsTable tr").show();

	$.each([ 'rope', 'hoop', 'ball', 'clubs', 'ribbon' ], function( index, value ) {
	    if (currentApparatus!='freehands' && value != currentApparatus) {
		$(".elementsTable tr:contains('" + value + "')").hide();
	    }
	});
    }

});
