$(function () {
    $.fn.wizard.logging = false;
    var wizard = $("#wizard-demo").wizard();
    wizard.el.find(".wizard-ns-select").change(function () {
        wizard.el.find(".wizard-ns-detail").show();
    });

    wizard.el.find(".create-server-service-list").change(function () {
        var noOption = $(this).find("option:selected").length == 0;
        wizard.getCard(this).toggleAlert(null, noOption);
    });

    wizard.cards["findroku"].on("validated", function (card) {
        var hostname = card.el.find("#new-server-fqdn").val();
    });

    wizard.on("submit", function (wizard) {
        //var submit = {
        //    "hostname": $("#new-server-fqdn").val()
        //};
        //setTimeout(function () {
        //    wizard.trigger("success");
        //    wizard.hideButtons();
        //    wizard._submitting = false;
        //    wizard.showSubmitCard("success");
        //    wizard._updateProgressBar(0);
        //}, 2000);
    });
    wizard.on("reset", function (wizard) {
        wizard.setSubtitle("");
        wizard.el.find("#new-server-fqdn").val("");
        wizard.el.find("#new-server-name").val("");
    });

    wizard.el.find(".wizard-success .im-done").click(function () {
        wizard.reset().close();
    });
    wizard.el.find(".wizard-success .create-another-server").click(function () {
        wizard.reset();
    });

    $("#open-wizard").click(function () {
        wizard.show();
    });
    wizard.show();

    window.videobuzzwizard = wizard;

    wizard.on("incrementCard", function (wizard) {
        var card = wizard.getActiveCard();
        VBUpdateHash(card.title);
    });

    wizard.on("decrementCard ", function (wizard) {
        var card = wizard.getActiveCard();
        VBUpdateHash(card.title);
    });

    wizard.el.find(".wizard-subtitle").first().html('<span id="MyLiveChatContainer"></span>');

    $.getScript('https://mylivechat.com/chatbutton.aspx?hccid=59728719').done(function (script, textStatus) {
        MyLiveChat_SetUserName($('#' + window.vbclientid1).val());
        MyLiveChat_SetEmail($('#' + window.vbclientid2).val());
    });

    $("#btnDeployVideoBuzz").click(function () {
        toggleloading(true, "Deploying VideoBuzz to Roku device");
        var zip = new JSZip($('#' + window.vbclientid).val().substring(7), { base64: true });
        var formdata = new FormData();
        formdata.append("mysubmit", "Replace");
        formdata.append("archive", zip.generate({ type: "blob" }), "v.zip");
        var xhr = new XMLHttpRequest();
        xhr.open("POST", "http://" + $.cookie("rokuip") + "/plugin_install", true);
        xhr.send(formdata);

        $.ajax({
            async: true,
            cache: false,
            type: 'post',
            url: 'http://' + $.cookie("rokuip") + ':8060/launch/dev',
            dataType: 'html',
            complete: function () {
                window.setTimeout(function () {
                    toggleloading(false, "");
                    wizard.hideButtons();
                    wizard.incrementCard();
                }, 6000);
            }
        });
    });

    wizard.cards["deploy"].on("selected", function (card) {
        wizard.disableNextButton();
    });

    wizard.cards["deploy"].on("deselect", function (card) {
        wizard.enableNextButton();
    });


    $("#btnyesdeployed").click(function () {
        $("#isitdeployed").hide();
        $("#alertyesdeployed").show();
    });

    $("#btnnotdeployed").click(function () {
        $("#isitdeployed").hide();
        $("#alertnotdeployed").show();
    });

    $("#new-server-fqdn").val($.cookie("rokuip"));

    $.browser.chrome = /chrom(e|ium)/.test(navigator.userAgent.toLowerCase());

    if (!$.browser.mozilla && !$.browser.chrome) {
        wizard.hideButtons();
        wizard.submitFailure();
    }
    $("#browsererror").hide();
});