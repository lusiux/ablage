$( document ).ready(function() {
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

	var ms = $( "#ms" ).magicSuggest({
		placeholder: 'Tags',
		data: [ %%JSONTAGLIST%% ],
		value: [ %%htmlTagsValueList%% ],
	});
	$("#cliTags").text( ms.getValue().join(","));
	$(ms).on('selectionchange', function(e,m){
		$("#cliTags").text(this.getValue().join(","));
	});

	var msSender = $( "#ms-sender" ).magicSuggest({
		maxSelection: 1,
		placeholder: 'Sender',
		data: [ %%jsonSenderList%% ],
		value: [ ],
	});
	$(msSender).on('selectionchange', function(e,m){
		$("#sender").text(this.getValue().join(","));
		$("#cliSender").text(this.getValue().join(","));

		var arr = this.getValue();

		$( ".senderTagItem").hide();
		for (var i = 0; i < arr.length; i++) {
			$( "#senderTags" + arr[i]).show();
		}
	});
	msSender.setValue([ %%htmlSenderValueList%% ]);
	$("#cliSender").text( msSender.getValue().join(","));
	$("#sender").text( msSender.getValue().join(","));

	$( "#datepicker" ).on('change', function() {
		$( "#cliDate" ).text( this.value );
		$( "#date" ).text( this.value );
	});
});
