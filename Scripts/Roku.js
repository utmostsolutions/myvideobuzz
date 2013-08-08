function loadedImage() {
    var URL = this.src;
    scannedRokus.push(getHostFromUrl(URL));
    ipCount++;
    //dbg("ipCount: " + ipCount);
    if (scannedRokus.length <= rokuCount) {
        if (ipPos < 255) {
            ipPos++;
            images[ipPos].src = URLS[ipPos];
            timeouts = setTimeout('cancelImage(' + ipPos + ');', 500);
        }
        setConfig('scannedRokus', scannedRokus.join(","));
        scanResults.innerHTML = "Scanning " + (254 - ipCount) + " addresses. " + scannedRokus.length + " Rokus found.";
        updateSelect();
    }
    if (scannedRokus.length >= rokuCount || ipCount >= 254 || ipPos >= 254) {
        scanButton.innerHTML = "Scan";
        ipCount = 0;
        ipPos = 0;
        scanning = false;
        scanResults.setAttribute("class", "hidden");
        stopFindRokus();
        clearTimeout(timeouts);
    }
}

function imageError() {
    ipCount++;
    scanResults.innerHTML = "Scanning " + (254 - ipCount) + " addresses. " + scannedRokus.length + " Rokus found.";
    //dbg("ipCount: " + ipCount);
    if (ipCount >= 254) {
        scanButton.innerHTML = "Scan";
        scanning = false;
        ipCount = 0;
        ipPos = 0;

        clearTimeout(timeouts);
        stopFindRokus();
        if (scannedRokus.length < 1) scanResults.innerHTML = "No Rokus Found. Check your network settings.";
        if (scannedRokus.length < 1) dbg("No Rokus Found. Check your network settings.");
    } else if (ipPos < 255) {
        ipPos++;
        images[ipPos].src = URLS[ipPos];
        timeouts = setTimeout('cancelImage(' + ipPos + ');', 500);
    }
}
function cancelImage(i) {
    //dbg('cancelImage:'+i);
    images[i].onload = null;
    images[i].onerror = null;
    //images[i].src=null;
    //      imageError();
    ipCount++;
    ipPos++;
    //dbg('ipPos:'+ipPos);
    scanResults.innerHTML = "Scanning " + (254 - ipCount) + " addresses. " + scannedRokus.length + " Rokus found.";
    if (ipCount >= 254) {
        scanButton.innerHTML = "Scan";
        scanning = false;
        ipCount = 0;
        ipPos = 0;

        clearTimeout(timeouts);
        stopFindRokus();
        if (scannedRokus.length < 1) scanResults.innerHTML = "No Rokus Found. Check your network settings.";
        if (scannedRokus.length < 1) dbg("No Rokus Found. Check your network settings.");
    } else {
        //dbg(URLS[ipPos]);
        if (scanning) images[ipPos].src = URLS[ipPos];
        if (scanning) timeouts = setTimeout('cancelImage(' + ipPos + ');', 500);
    }
}


function findRokus() {
    if (!scanning) {
        scannedRokus = new Array;
        setRokuCount();
        this.innerHTML = "Stop";
        scanResults.setAttribute("class", "visible");
        scanResults.innerHTML = "Scanning " + (254 - ipCount) + " addresses. " + scannedRokus.length + " Rokus found.";
        scanning = true;
        for (i = 1; i < 255; i++) {
            images[i - 1] = new Image();
            URLS[i - 1] = "http://" + myNetwork + "." + i + ":8060/query/icon/11";
            images[i - 1].id = "ip-" + i;
            images[i - 1].onload = loadedImage;
            images[i - 1].onerror = imageError;

        }
        ipPos = 0;
        images[ipPos].src = URLS[ipPos];
        timeouts = setTimeout('cancelImage(' + ipPos + ');', 500);
    }
    else {
        scanning = false;
        this.innerHTML = "Scan";
        scanResults.setAttribute("class", "hidden");
        ipPos = 255;
        ipCount = 0;
        stopFindRokus();
        setConfig('scannedRokus', scannedRokus.join(","));
        updateSelect();
    }
}