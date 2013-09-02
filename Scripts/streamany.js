function setServerName(card) {
    var host = $("#new-server-fqdn").val();
    var displayName = host;

    //card.wizard.setSubtitle(displayName);
    card.wizard.el.find(".create-server-name").text(displayName);
}

function developermodeenabled(card) {
    var host = $("#new-server-fqdn").val();

    verifyDeveloperMode(host, function () { }, function () {
        window.videobuzzwizard.decrementCard();
        $("#remotesequence").show();
    })
}

function validateIP(ipaddr) {
    //Remember, this function will validate only Class C IP.
    //change to other IP Classes as you need
    var re = /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/; //regex. check for digits and in
    //all 4 quadrants of the IP
    if (re.test(ipaddr)) {
        //split into units with dots "."
        var parts = ipaddr.split(".");
        //if the first unit/quadrant of the IP is zero
        if (parseInt(parseFloat(parts[0])) == 0) {
            return false;
        }
        //if the fourth unit/quadrant of the IP is zero
        if (parseInt(parseFloat(parts[3])) == 0) {
            return false;
        }
        //if any part is greater than 255
        for (var i = 0; i < parts.length; i++) {
            if (parseInt(parseFloat(parts[i])) > 255) {
                return false;
            }
        }

        return true;
    }
    else {
        return false;
    }
}

function validateFQDN(val) {
    return /^[a-z0-9-_]+(\.[a-z0-9-_]+)*\.([a-z]{2,4})$/.test(val);
}

function fqdn_or_ip(el) {
    var val = el.val();
    val = val.replace(/\s/g, "");
    $.cookie("rokuip", val);
    ret = {
        status: true
    };
    if (!validateIP(val)) {
        ret.status = false;
        ret.msg = "Invalid IP address. IP Address will in 192.168.1.1 format.";
        return ret;
    }

    verifyRokuDevice(val, function () {
        verifyDeveloperMode(val, function () {
            window.videobuzzwizard.incrementCard();
            //$("#remotesequence").show();
        }, function () {
        })

    }, function () {
        window.videobuzzwizard.decrementCard();
        var input = $("#new-server-fqdn");
        window.videobuzzwizard.errorPopover(input, "Not a valid Roku IP Address. Please use instructions below to find Roku IP Address.");
    });



    return ret;
}

function valid_termsandconditions(el) {
    ret = {
        status: true
    };
    if (!el.is(':checked')) {
        ret.status = false;
        ret.msg = "You need to agree terms and conditions to continue with installation.";
        $("#termsandconditionspanel").scrollTop($("#termsandconditionspanel")[0].scrollHeight);
    }
    return ret;
}

function toggleloading(show, msg) {
    if (show) {
        $("#loading-image-msg").html(msg);
        $('#loading').show();
    }
    else {
        $("#loading-image-msg").html("");
        $('#loading').hide();
    }
}

function verifyRokuDevice(rokuip, successCallback, failCallback) {
    toggleloading(true, "Connecting to Roku device");
    var image = new Image();
    url = 'http://' + rokuip + ':8060/query/icon/11';
    image.onload = function () {
        //var imgurl = this.src;
        //var deviceip = imgurl.split('/')[2].split(':')[0];
        toggleloading(false, "");
        if (successCallback != null) {
            successCallback();
        }
    };
    image.onerror = function () {
        toggleloading(false, "");
        if (failCallback != null) {
            failCallback();
        }
    };
    image.src = url;
}

function verifyDeveloperMode(rokuip, successCallback, failCallback) {
    toggleloading(true, "Connecting to Roku device");
    $.ajax({
        dataType: 'jsonp',
        url: "http://" + rokuip + "/plugin_install",
        type: "GET",
        timeout: 10000,
        crossDomain: true,
        headers: {
            "X-Requested-With": "XMLHttpRequest"
        },
        success: function (response) {
            //console.log(response);
            toggleloading(false, "");
            if (successCallback != null) {
                successCallback();
            }
        },
        error: function (x, t, m) {
            //console.log(x);
            //console.log(t);
            //console.log(m);
            toggleloading(false, "");
            if (t === "timeout") {
                if (failCallback != null) {
                    failCallback();
                }
            } else {
                if (successCallback != null) {
                    successCallback();
                }
            }
        }
    });
}

function VBUpdateHash(h) {
    if (h != "")
        location.hash = "#" + h;
}

