$( "#cliSender" ).hide();
$( "#cliSender" ).text($( "#sender" ).text());
$( "#cliSender" ).show();

$( ".senderTagItem").hide();
$( "#senderTags" + $( "#sender" ).text()).show();

$( "#datepicker" ).datepicker({
	dateFormat: "dd.mm.yy",
});

$( "#cliDate" ).hide();
$( "#cliDate" ).text($( "#datepicker" ).val());
$( "#cliDate" ).show();

$( "#dateChoice" ).on('change', function() {
	$( "#cliDate" ).text( this.value );
	$( "#datepicker" ).val( this.value );
});

$( "#senderChoice" ).on('change', function() {
	$( "#cliSender" ).text( this.value );
	$( "#sender" ).text( this.value );
});

$( "#datepicker" ).on('change', function() {
	$( "#cliDate" ).text( this.value );
	$( "#date" ).text( this.value );
});
