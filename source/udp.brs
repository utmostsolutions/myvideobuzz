'********************************************************************
' Initializes the UDP objects for use in the application.
' @param youtube the current youtube object
'********************************************************************
Sub MulticastInit(youtube as Object)
    msgPort = createobject("roMessagePort")
    udp = createobject("roDatagramSocket")
    udp.setMessagePort(msgPort) 'notifications for udp come to msgPort
    addr = createobject("roSocketAddress")
    addr.setPort(6789)
    addr.SetHostName("224.0.0.115")
    udp.setAddress(addr)
    if (not(udp.setSendToAddress(addr))) then
        print ("Failed to set send to address")
        return
    end if
    ' Only local subnet
    udp.SetMulticastTTL(1)
    if (not(udp.SetMulticastLoop(false))) then
        print("Failed to disable multicast loop")
    end if
    ' Join the multicast group
    udp.joinGroup(addr)
    udp.NotifyReadable(true)
    udp.NotifyWritable(false)

    youtube.udp_socket = udp
    youtube.mp_socket = msgPort
End Sub

'********************************************************************
' Determines if someone on the network has tried to query for other videos on the LAN
' Listens for active video queries, and responds if necessary
'********************************************************************
Sub CheckForMCast()
    regexNewline = CreateObject( "roRegex", "\n", "ig" )
    youtube = LoadYouTube()
    if (youtube.mp_socket = invalid OR youtube.udp_socket = invalid) then
        print("CheckForMCast: Invalid Message Port or UDP Socket")
        return
    end if

    message = youtube.mp_socket.GetMessage()
    ' Flag to track if a response is necessary -- we only want to respond once,
    ' even if we find multiple queries available on the socket
    mvbRespond = false
    while (message <> invalid)
        if (type(message) = "roSocketEvent") then
            data = youtube.udp_socket.receiveStr(4096) ' max 4096 characters

            ' Replace newlines
            data = regexNewline.ReplaceAll( data, "" )
            ' print("Received " + Left(data, 2) + " from " + Mid(data, 3))
            if ((Left(data, 2) = "1?") AND (Mid(data, 3) <> youtube.device_id)) then
                ' Nothing to do if there's no video to watch
                if (youtube.activeVideo <> invalid) then
                    mvbRespond = true
                end if
            else if ((Left(data, 2) = "2:")) then ' Allow push of videos from other sources on the LAN (not implemented within this source)
                ' print("Received force: " + Mid(data, 3))
                youtube.activeVideo = ParseJson(Mid(data, 3))
            else if ((Left(data, 2) = "1:")) then
                ' print("Received udp response: " + Mid(data, 3))
            end if
        end if
        ' This effectively drains the receive queue
        message = wait(10, youtube.mp_socket)
    end while
    if (mvbRespond = true) then
        ' Cache the video's XML since we don't want it in the JSON
        xml = youtube.activeVideo.xml
        ' Zero out the xml prior to conversion to JSON
        youtube.activeVideo.xml = invalid
        json = SimpleJSONBuilder(youtube.activeVideo)
        if (json <> invalid) then
            ' Replace all newlines in the JSON
            json = regexNewline.ReplaceAll(json, "")
            youtube.udp_socket.SendStr("1:" +  json)
        end if
        ' PrintAA(youtube.activeVideo)
        ' print(SimpleJSONBuilder(youtube.activeVideo))
        youtube.activeVideo.xml = xml
    end if
End Sub

'********************************************************************
' Determines if there are available videos on the LAN to continue watching
' Multicasts a query for other listening devices to respond with their currently-active video
' This function is a callback handler for the main menu
' @param youtube the current youtube object
'********************************************************************
Sub CheckForLANVideos(youtube as Object)
    regexNewline = CreateObject( "roRegex", "\n", "ig" )
    jsonMetadata = []
    if (youtube.mp_socket = invalid OR youtube.udp_socket = invalid) then
        print("CheckForMCast: Invalid Message Port or UDP Socket")
        return
    end if
    dialog = ShowPleaseWait("Searching for videos on your LAN")
    ' Multicast query
    youtube.udp_socket.SendStr("1?" + youtube.device_id)
    ' Wait a maximum of 5 seconds for a response
    t = CreateObject("roTimespan")
    message = wait(2500, youtube.mp_socket)
    while (message <> invalid OR t.TotalSeconds() < 5)
        if (type(message) = "roSocketEvent") then
            data = youtube.udp_socket.receiveStr(4096) ' max 4096 characters
            ' print("Received " + Left(data, 2) + " from " + Mid(data, 3))
            ' Replace newlines -- this WILL screw up JSON parsing
            data = regexNewline.ReplaceAll( data, "" )
            if ((Left(data, 2) = "1:")) then
                response = Mid(data, 3)
                ' print("Received udp response: " + response)
                jsonObj = ParseJson(response)
                if (jsonObj <> invalid) then
                    jsonMetadata.Push(jsonObj)
                end if
            end if
        ' else the message is invalid
        end if
        ' If we continue to receive valid roSocketEvent messages, we still want to limit the query to 5 seconds
        if (t.TotalSeconds() > 5 OR jsonMetadata.Count() > 50) then
            exit while
        end if
        message = wait(100, youtube.mp_socket)
    end while
    print("Found " + tostr(jsonMetadata.Count()) + " LAN Videos")
    dialog.Close()
    youtube.DisplayVideoListFromMetadataList(jsonMetadata, "LAN Videos", invalid, invalid, invalid)
End Sub
