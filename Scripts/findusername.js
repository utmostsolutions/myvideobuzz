$(function () {
    if ($.browser.msie) {
        $("#ieerror").show();
        $("#instructions").hide();
    }
    else {


        function showStatus() {
            var hash = window.location.hash;
            if (hash === "") {
            }
            else if (hash === "#error=access_denied") {
                $("#deniedaccess").show();

            }
            else if (hash.indexOf("#access_token") == 0) {
                var params = {}, queryString = hash.substring(1), regex = /([^&=]+)=([^&]*)/g, m;
                while (m = regex.exec(queryString)) {
                    params[decodeURIComponent(m[1])] = decodeURIComponent(m[2]);
                }
                if (typeof params.access_token != "undefined") {
                    $.support.cors = true;
                    //console.log("aaa");
                    $.ajax({
                        type: 'GET',
                        dataType: "xml",
                        crossDomain: true,
                        url: "https://gdata.youtube.com/feeds/api/users/default?v=2.1",
                        beforeSend: function (xhr) {
                            xhr.setRequestHeader('Content-Type', 'application/atom+xml');
                            xhr.setRequestHeader('Authorization', 'AuthSub token="' + params.access_token + '"');
                            xhr.setRequestHeader('X-GData-Key', 'key="AI39si6eUMQ7Pt1GW0ItUDxjzk5l_MppL_LfBE6EuYGyfRUMyEHdSVDP1fcqT0CgqyJjrcc-a68zWPYpW0NzpINuoPFwqEIuCw"');
                            xhr.setRequestHeader('GData-Version', '2');
                        },
                        complete: function (oData, status) {
                            //console.log("chrome " + oData.responseText);
                            var found = false;
                            if (status === "success") {
                                var myregexp = /<yt:username(.*)>(.*)<\/yt:username>/im;
                                var match = myregexp.exec(oData.responseText);
                                if (match != null) {
                                    found = true;
                                    $('#ytusername').html('<h3>Your youtube username : ' + match[2] + '</h3>');
                                    $('#instructions').html('If you want to change your username, Here are instructions.<br/><br/><center><iframe width="560" height="315" src="http://www.youtube.com/embed/sxw1PabE1Dc?rel=0" frameborder="0" allowfullscreen></iframe></center>');
                                    $('#ytusername').show();
                                    //$("#instructions").hide();
                                }
                                else {
                                    $('#ytusername').html('Something went wrong, please try again.');
                                    $('#ytusername').show();
                                }
                            }
                        },
                        error: function (xhr, ajaxOptions, thrownError) {
                            if (thrownError === "NoLinkedYouTubeAccount") {
                                $('#nolinkaccount').show();
                                $("#instructions").hide();
                            }
                            else {
                                $("#deniedaccess").html('Something went wrong, please try again. Here is Error Message: ' + xhr.status + " " + thrownError);
                                $('#deniedaccess').show();
                            }
                        }
                    });
                }
            }
        }

        $(window).bind('hashchange', showStatus);
        showStatus();
    }
});