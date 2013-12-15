
Function LoadYouTube() As Object
    ' global singleton
    return m.youtube
End Function

Function InitYouTube() As Object
    ' constructor
    this = CreateObject("roAssociativeArray")
    this.device_id = CreateObject("roDeviceInfo").GetDeviceUniqueId()
    this.oauth_prefix = "https://www.google.com/accounts"
    this.link_prefix = "http://roku.toasterdesigns.net"
    this.devKey = "AI39si7xeR7W6rGgB9pZ3xBKHZnPVlBBdU3HZnhFXg8g7_3V8rplFNAT6rx_SVRzLRPhhNN-JARUjVg4JKGI5xjO00lK_Omb7g"
    this.protocol = "http"
    this.scope = this.protocol + "://gdata.youtube.com"
    this.prefix = this.scope + "/feeds/api"
    this.currentURL = ""
    this.searchLengthFilter = ""
    tmpLength = RegRead("length", "Search")
    if (tmpLength <> invalid) then
        this.searchLengthFilter = tmpLength
    end if
    this.searchDateFilter = ""
    tmpDate = RegRead("date", "Search")
    if (tmpDate <> invalid) then
        this.searchDateFilter = tmpDate
    end if

    this.searchSort = ""
    tmpSort = RegRead("sort", "Search")
    if (tmpSort <> invalid) then
        this.searchSort = tmpSort
    end if

    this.CurrentPageTitle = ""
    this.screen       = invalid
    this.video        = invalid

    ' Caches the latest video the user has watched
    ' This is used when sending out the video over the network
    this.activeVideo = invalid

    'API Calls
    this.ExecServerAPI = youtube_exec_api

    'Search
    this.SearchYouTube = youtube_search

    'User videos
    this.BrowseUserVideos = youtube_user_videos

    ' Playlists
    this.BrowseUserPlaylists = BrowseUserPlaylists_impl

    'related
    this.ShowRelatedVideos = youtube_related_videos

    'Videos
    this.DisplayVideoListFromVideoList = DisplayVideoListFromVideoList_impl
    this.DisplayVideoListFromMetadataList = DisplayVideoListFromMetadataList_impl
    this.FetchVideoList = FetchVideoList_impl
    this.VideoDetails = VideoDetails_impl
    this.newVideoListFromXML = youtube_new_video_list
    this.newVideoFromXML = youtube_new_video
    this.ReturnVideoList = youtube_return_video

    'Categories
    this.CategoriesListFromXML  = CategoriesListFromXML_impl

    this.BuildButtons = BuildButtons_impl

    'Settings
    this.BrowseSettings = youtube_browse_settings
    this.About = youtube_about
    this.AddAccount = youtube_add_account
    this.RedditSettings = EditRedditSettings
	this.ClearHistory = youtube_clear_history

	' History
	this.ShowHistory = show_history
	this.AddHistory = add_history
	this.GetVideoObject = get_video_object
	this.GetVideoDetails = get_video_details

    this.udp_socket = invalid
    this.mp_socket  = invalid

    ' Regex found on the internets here: http://stackoverflow.com/questions/3452546/javascript-regex-how-to-get-youtube-video-id-from-url
    ' Pre-compile the YouTube video ID regex
    this.ytIDRegex = CreateObject("roRegex", ".*(?:youtu.be\/|v\/|u\/\w\/|embed\/|watch\?v=)([^#\&\?]*).*", "")

    return this
End Function


Function youtube_exec_api(request As Dynamic, username = "default" As Dynamic) As Object
    'oa = Oauth()

    if (username = invalid) then
        username = ""
    else
        username = "users/" + username + "/"
    end if

    method = "GET"
    url_stub = request
    postdata = invalid
    headers = { }

    if (type(request) = "roAssociativeArray") then
        if (request.url_stub <> invalid) then
            url_stub = request.url_stub
        end if
        if (request.postdata <> invalid) then
            postdata = request.postdata
            method = "POST"
        end if
        if (request.headers <> invalid) then
            headers = request.headers
        end if
        if (request.method <> invalid) then
            method = request.method
        end if
    end if

    ' Cache the current URL for refresh operations
    m.currentURL = url_stub

    if (Instr(0, url_stub, "http://") OR Instr(0, url_stub, "https://")) then
        http = NewHttp(url_stub)
    else
        http = NewHttp(m.prefix + "/" + username + url_stub)
    end if

	'print "URL " + http.GetURL()

    'if not headers.DoesExist("X-GData-Key") then headers.AddReplace("X-GData-Key", "key="+m.devKey)
    'if not headers.DoesExist("GData-Version") then headers.AddReplace("GData-Version", "2")

    http.method = method
    http.AddParam("v","2","urlParams")
    'oa.sign(http,true)

    'print "----------------------------------"
    if (Instr(1, request, "pkg:/") > 0) then
        rsp = ReadAsciiFile(request)
    else if (postdata <> invalid) then
        rsp = http.PostFromStringWithTimeout(postdata, 10, headers)
        'print "postdata:",postdata
    else
        rsp = http.getToStringWithTimeout(10, headers)
    end if


    'print "----------------------------------"
    'print rsp
    'print "----------------------------------"

    xml = ParseXML(rsp)

    returnObj = CreateObject("roAssociativeArray")
    returnObj.xml = xml
    returnObj.status = http.status
    if (Instr(1, request, "pkg:/") < 0) then
        returnObj.error = handleYoutubeError(returnObj)
    end if

    return returnObj
End Function

Function handleYoutubeError(rsp) As Dynamic
    ' Is there a status code? If not, return a connection error.
    if (rsp.status = invalid) then
        return ShowConnectionFailed()
    end if
    ' Don't check for errors if the response code was a 2xx or 3xx number
    if (int(rsp.status / 100) = 2 OR int(rsp.status / 100) = 3) then
        return ""
    end if

    if (not(isxmlelement(rsp.xml))) then
        return ShowErrorDialog("API return invalid. Try again later", "Bad response")
    end if

    error = rsp.xml.GetNamedElements("error")[0]
    if (error = invalid) then
        ' we got an unformatted HTML response with the error in the title
        error = rsp.xml.GetChildElements()[0].GetChildElements()[0].GetText()
    else
        error = error.GetNamedElements("internalReason")[0].GetText()
    end if

    ShowDialog1Button("Error", error, "OK", true)
    return error
End Function

'********************************************************************
' YouTube User uploads
'********************************************************************
Sub youtube_user_videos(username As String, userID As String)
    m.FetchVideoList("users/"+userID+"/uploads?orderby=published", "Videos By "+username, invalid)
End Sub

'********************************************************************
' YouTube User Playlists
'********************************************************************
Sub BrowseUserPlaylists_impl(username As String, userID As String)
    m.FetchVideoList("users/" + userID + "/playlists?max-results=50", username + "'s Playlists", invalid, true)
End Sub

'********************************************************************
' YouTube Related Videos
'********************************************************************
Sub youtube_related_videos(video As Object)
    m.FetchVideoList("videos/"+ video.id +"/related?v=2", "Related Videos", invalid)
    'GetYTBase("videos/" + showList[showIndex].ContentId + "/related?v=2&start-index=1&max-results=50"))
End Sub

'********************************************************************
' YouTube Poster/Video List Utils
'********************************************************************
Sub FetchVideoList_impl(APIRequest As Dynamic, title As String, username As Dynamic, categories=false, message = "Loading..." as String)

    'fields = m.FieldsToInclude
    'if Instr(0, APIRequest, "?") = 0 then
    '    fields = "?"+Mid(fields, 2)
    'end if

    screen = uitkPreShowPosterMenu("flat-episodic-16x9", title)
    screen.showMessage(message)

    response = m.ExecServerAPI(APIRequest, username)
    if (response.status = 403) then
        ShowErrorDialog(title + " may be private, or unavailable at this time. Try again.", "403 Forbidden")
        return
    end if
    if (not(isxmlelement(response.xml))) then
        ShowConnectionFailed()
        return
    end if

    ' Everything is OK, display the list
    xml = response.xml
    if (categories = true) then
        categories = m.CategoriesListFromXML(xml.entry)
        'PrintAny(0, "categoryList:", categories)
        m.DisplayVideoListFromVideoList([], title, xml.link, screen, categories)
    else
        videos = m.newVideoListFromXML(xml.entry)
        m.DisplayVideoListFromVideoList(videos, title, xml.link, screen, invalid)
    end if
End Sub


Function youtube_return_video(APIRequest As Dynamic, title As String, username As Dynamic)
    xml = m.ExecServerAPI(APIRequest, username)["xml"]
    if (not(isxmlelement(xml))) then
        ShowConnectionFailed()
        return []
    end if

    videos = m.newVideoListFromXML(xml.entry)
    metadata = GetVideoMetaData(videos)

    if (xml.link <> invalid) then
        for each link in xml.link
            if (link@rel = "next") then
                metadata.Push({shortDescriptionLine1: "More Results", action: "next", pageURL: link@href, HDPosterUrl:"pkg:/images/icon_next_episode.jpg", SDPosterUrl:"pkg:/images/icon_next_episode.jpg"})
            else if (link@rel = "previous") then
                metadata.Unshift({shortDescriptionLine1: "Back", action: "prev", pageURL: link@href, HDPosterUrl:"pkg:/images/icon_prev_episode.jpg", SDPosterUrl:"pkg:/images/icon_prev_episode.jpg"})
            end if
        end for
    end if

    return metadata
End Function

Sub DisplayVideoListFromVideoList_impl(videos As Object, title As String, links=invalid, screen = invalid, categories = invalid, metadataFunc = GetVideoMetaData as Function)
    if (categories = invalid) then
        metadata = metadataFunc(videos)
    else
        metadata = videos
    end if
    m.DisplayVideoListFromMetadataList(metadata, title, links, screen, categories)
End Sub

Sub DisplayVideoListFromMetadataList_impl(metadata As Object, title As String, links=invalid, screen = invalid, categories = invalid)
    if (screen = invalid) then
        screen = uitkPreShowPosterMenu("flat-episodic-16x9", title)
        screen.showMessage("Loading...")
    end if
    m.CurrentPageTitle = title

    if (categories <> invalid) then
        categoryList = CreateObject("roArray", 100, true)
        for each category in categories
            categoryList.Push(category.title)
        next

        oncontent_callback = [categories, m,
            function(categories, youtube, set_idx)
                'PrintAny(0, "category:", categories[set_idx])
                if (youtube <> invalid AND categories.Count() > 0) then
                    return youtube.ReturnVideoList(categories[set_idx].link, youtube.CurrentPageTitle, invalid)
                else
                    return []
                end if
            end function]


        onclick_callback = [categories, m,
            function(categories, youtube, video, category_idx, set_idx)
                if (video[set_idx]["action"] <> invalid) then
                    return { isContentList: true, content: youtube.ReturnVideoList(video[set_idx]["pageURL"], youtube.CurrentPageTitle, invalid) }
                else
                    youtube.VideoDetails(video[set_idx], youtube.CurrentPageTitle, video, set_idx)
                    return { isContentList: false, content: video}
                end if
            end function]
        uitkDoCategoryMenu(categoryList, screen, oncontent_callback, onclick_callback, onplay_callback)
    else if (metadata.Count() > 0) then
        for each link in links
            if (type(link) = "roXMLElement") then
                if (link@rel = "next") then
                    metadata.Push({shortDescriptionLine1: "More Results", action: "next", pageURL: link@href, HDPosterUrl:"pkg:/images/icon_next_episode.jpg", SDPosterUrl:"pkg:/images/icon_next_episode.jpg"})
                else if (link@rel = "previous") then
                    metadata.Unshift({shortDescriptionLine1: "Back", action: "prev", pageURL: link@href, HDPosterUrl:"pkg:/images/icon_prev_episode.jpg", SDPosterUrl:"pkg:/images/icon_prev_episode.jpg"})
                end if
            else if (type(link) = "roAssociativeArray") then
                if (link.type = "next") then
                    metadata.Push({shortDescriptionLine1: "More Results", action: "next", pageURL: link.href, HDPosterUrl:"pkg:/images/icon_next_episode.jpg", SDPosterUrl:"pkg:/images/icon_next_episode.jpg", func: link.func})
                else if (link.type = "previous") then
                    metadata.Unshift({shortDescriptionLine1: "Back", action: "prev", pageURL: link.href, HDPosterUrl:"pkg:/images/icon_prev_episode.jpg", SDPosterUrl:"pkg:/images/icon_prev_episode.jpg", func: link.func})
                end if
            end if
        end for

        onselect = [1, metadata, m,
            function(video, youtube, set_idx)
                if (video[set_idx]["func"] <> invalid) then
                    video[set_idx]["func"](youtube, video[set_idx]["pageURL"])
                else if (video[set_idx]["action"] <> invalid) then
                    youtube.FetchVideoList(video[set_idx]["pageURL"], youtube.CurrentPageTitle, invalid)
                else
                    youtube.VideoDetails(video[set_idx], youtube.CurrentPageTitle, video, set_idx)
                end if
            end function]
        uitkDoPosterMenu(metadata, screen, onselect, onplay_callback)
    else
        uitkDoMessage("No videos found.", screen)
    end if
End Sub

'********************************************************************
' Callback function for when the user hits the play button from the video list
' screen.
' @param theVideo the video metadata object that should be played.
'********************************************************************
Sub onplay_callback(theVideo as Object)
    result = video_get_qualities(theVideo)
    if (result = 0) then
        DisplayVideo(theVideo)
    end if
End Sub

'********************************************************************
' Creates the list of categories from the provided XML
' @param xmlList the XML to create the category list from.
' @return an roList, which will be sorted by the yt:unreadCount if the XML
'         represents a list of subscriptions.
'         each category has the following members:
'           title
'           link
'********************************************************************
Function CategoriesListFromXML_impl(xmlList As Object) As Object
    'print "CategoriesListFromXML_impl init"
    categoryList  = CreateObject("roList")
    for each record in xmlList
        ''printAny(0, "xmlList:", record)
        category        = CreateObject("roAssociativeArray")
        category.title  = record.GetNamedElements("title").GetText()
        category.link   = validstr(record.content@src)

        if (record.GetNamedElements("yt:unreadCount").Count() > 0) then
            category.unreadCount% = record.GetNamedElements("yt:unreadCount").GetText().toInt()
        else
            category.unreadCount% = 0
        end if
        ' print (category.title + " unreadCount: " + tostr(category.unreadCount%))

        if (isnullorempty(category.link)) then
            links = record.link
            for each link in links
                if (Instr(1, link@rel, "user.uploads") > 0) then
                    category.link = validstr(link@href) + "&max-results=50"
                end if
            next
        end if

        categoryList.Push(category)
    next
    Sort(categoryList, Function(obj as Object) as Integer
            return obj.unreadCount%
        End Function)
    return categoryList
End Function



'********************************************************************
' Creates a list of video metadata objects from the provided XML
' @param xmlList the XML to create the list of videos from
' @return an roList of video metadata objects
'********************************************************************
Function youtube_new_video_list(xmlList As Object) As Object
    'print "youtube_new_video_list init"
    videolist = CreateObject("roList")
    for each record in xmlList
        video = m.newVideoFromXML(record)
        videolist.Push(video)
    next
    return videolist
End Function

Function youtube_new_video(xml As Object) As Object
    video               = CreateObject("roAssociativeArray")
    video.youtube       = m
    video.xml           = xml
    video.GetID         = get_xml_id
    video.GetAuthor     = get_xml_author
    video.GetUserID     = function():return m.xml.GetNamedElements("media:group")[0].GetNamedElements("yt:uploaderId")[0].GetText():end function
    video.GetTitle      = function():return m.xml.title[0].GetText():end function
    video.GetCategory   = function():return m.xml.GetNamedElements("media:group")[0].GetNamedElements("media:category")[0].GetText():end function
    video.GetDesc       = get_desc
    video.GetLength     = GetLength_impl
    video.GetUploadDate = GetUploadDate_impl
    video.GetRating     = get_xml_rating
    video.GetThumb      = get_xml_thumb
    'video.GetLinks     = function():return m.xml.GetNamedElements("link"):end function
    'video.GetURL       = video_get_url
    return video
End Function

Function GetVideoMetaData(videos As Object)
    metadata = []

    for each video in videos
        meta = CreateObject("roAssociativeArray")
        meta.ContentType = "movie"
        meta["ID"]                     = video.GetID()
        meta["Author"]                 = video.GetAuthor()
        meta["TitleSeason"]            = video.GetTitle()
        meta["Title"]                  = video.GetAuthor() + "  - " + get_length_as_human_readable(video.GetLength())
        meta["Actors"]                 = meta.Author
        meta["Description"]            = video.GetDesc()
        meta["Categories"]             = video.GetCategory()
        meta["StarRating"]             = video.GetRating()
        meta["ShortDescriptionLine1"]  =  meta.TitleSeason
        meta["ShortDescriptionLine2"]  = meta.Title
        meta["SDPosterUrl"]            = video.GetThumb()
        meta["HDPosterUrl"]            = video.GetThumb()
        meta["Length"]                 = video.GetLength().toInt()
        meta["xml"]                    = video.xml
        meta["UserID"]                 = video.GetUserID()
        meta["ReleaseDate"]            = video.GetUploadDate()
        meta["StreamFormat"]           = "mp4"
        meta["Live"]                   = false
        meta["Streams"]                = []
        meta["PlayStart"]              = 0
        meta["SwitchingStrategy"]      = "no-adaptation"
        'meta.StreamBitrates=[]
        'meta.StreamQualities=[]
        'meta.StreamUrls=[]

        metadata.Push(meta)
    end for

    return metadata
End Function

Function get_desc() As Dynamic
    desc = m.xml.GetNamedElements("media:group")[0].GetNamedElements("media:description")
    if (desc.Count() > 0) then
        return Left(desc[0].GetText(), 300)
    end if
    return invalid
End Function

'*******************************************
'  Returns the length of the video from the yt:duration element:
'  <yt:duration seconds=val>
'*******************************************
Function GetLength_impl() As Dynamic
    durations = m.xml.GetNamedElements("media:group")[0].GetNamedElements("yt:duration")
    if (durations.Count() > 0) then
        return durations.GetAttributes()["seconds"]
    end if
    return "0"
End Function

'*******************************************
'  Returns the date the video was uploaded, from the yt:uploaded element:
'  <yt:uploaded>val</yt:uploaded>
'*******************************************
Function GetUploadDate_impl() As Dynamic
    uploaded = m.xml.GetNamedElements("media:group")[0].GetNamedElements("yt:uploaded")
    if (uploaded.Count() > 0) then
        dateText = uploaded.GetText()
        'dateObj = CreateObject("roDateTime")
        ' The value from YouTube has a 'Z' at the end, we need to strip this off, or else
        ' FromISO8601String() can't parse the date properly
        'dateObj.FromISO8601String(Left(dateText, Len(dateText) - 1))
        'return tostr(dateObj.GetMonth()) + "/" + tostr(dateObj.GetDayOfMonth()) + "/" + tostr(dateObj.GetYear())
        return Left(dateText, 10)
    end if
    return ""
End Function

'*******************************************
'  Returns the length of the video in a human-friendly format
'  i.e. 3700 seconds becomes: 1h 1m
'  TODO: use utility functions in generalUtils
'*******************************************
Function get_length_as_human_readable(length As Dynamic) As String
    if (type(length) = "roString") then
        len% = length.ToInt()
    else if (type(length) = "roInteger") then
        len% = length
    else
        return "Unknown"
    end if

    if ( len% > 0 ) then
        hours%   = FIX(len% / 3600)
        len% = len% - (hours% * 3600)
        minutes% = FIX(len% / 60)
        seconds% = len% MOD 60
        if ( hours% > 0 ) then
            return Stri(hours%) + "h" + Stri(minutes%) + "m"
        else
            return Stri(minutes%) + "m" + Stri(seconds%) + "s"
        end if
    else if ( len% = 0 ) then
        return "Live Stream"
    end if
    ' Default return
    return "Unknown"
End Function

Function get_xml_id() As Dynamic
    videoid=m.xml.GetNamedElements("media:group")[0].GetNamedElements("yt:videoid")
    if (videoid<>invalid and videoid.Count() > 0) then
		return videoid[0].GetText()
    end if
End Function

Function get_xml_author() As Dynamic
    credits=m.xml.GetNamedElements("media:group")[0].GetNamedElements("media:credit")
    if (credits<>invalid and credits.Count() > 0) then
        for each author in credits
            if (author.GetAttributes()["role"] = "uploader") then
                return author.GetAttributes()["yt:display"]
            end if
        end for
    end if
End Function

Function get_xml_rating() As Dynamic
    if (m.xml.GetNamedElements("gd:rating").Count() > 0) then
        return Int(m.xml.GetNamedElements("gd:rating").GetAttributes()["average"].toFloat() * 20)
    end if
    return invalid
End Function

Function get_xml_thumb() As Dynamic
    thumbs=m.xml.GetNamedElements("media:group")[0].GetNamedElements("media:thumbnail")
    if (thumbs.Count() > 0) then
        for each thumb in thumbs
            if (thumb.GetAttributes()["yt:name"] = "mqdefault") then
                return thumb.GetAttributes()["url"]
            end if
        end for
        return m.xml.GetNamedElements("media:group")[0].GetNamedElements("media:thumbnail")[0].GetAttributes()["url"]
    end if
    return "pkg:/images/icon_s.jpg"
End Function


'********************************************************************
' YouTube video details roSpringboardScreen
'********************************************************************
Sub VideoDetails_impl(theVideo As Object, breadcrumb As String, videos=invalid, idx=invalid)
    p = CreateObject("roMessagePort")
    screen = CreateObject("roSpringboardScreen")
    screen.SetMessagePort(p)

	' If it is history get Details from ID
	if (theVideo["IsHistory"] <> invalid) then
		theVideo = m.GetVideoDetails(theVideo)
	end if

    m.screen    = screen
    m.video     = theVideo
    screen.SetDescriptionStyle("movie")
    if (theVideo.StarRating = invalid) then
        screen.SetStaticRatingEnabled(false)
    end if
    if (videos.Count() > 1) then
        screen.AllowNavLeft(true)
        screen.AllowNavRight(true)
    end if
    screen.SetPosterStyle("rounded-rect-16x9-generic")
    screen.SetDisplayMode("zoom-to-fill")
    screen.SetBreadcrumbText(breadcrumb, "Video")

    buttons = m.BuildButtons()

    screen.SetContent(m.video)
    screen.Show()

    while (true)
        msg = wait(2000, screen.GetMessagePort())
        if (type(msg) = "roSpringboardScreenEvent") then
            if (msg.isScreenClosed()) then
                'print "Closing springboard screen"
                exit while
            else if (msg.isButtonPressed()) then
                'print "Button pressed: "; msg.GetIndex(); " " msg.GetData()
                if (msg.GetIndex() = 0) then ' Play/Resume
                    result = video_get_qualities(m.video)
                    if (result = 0) then
                        DisplayVideo(m.video)
                        buttons = m.BuildButtons()
                    end if
                else if (msg.GetIndex() = 5) then ' Play from beginning
                    m.video["PlayStart"] = 0
                    result = video_get_qualities(m.video)
                    if (result = 0) then
                        DisplayVideo(m.video)
                        buttons = m.BuildButtons()
                    end if
                else if (msg.GetIndex() = 1) then ' Play All
                    for i = idx to videos.Count() - 1  Step +1
                        selectedVideo = videos[i]
                        result = video_get_qualities(selectedVideo)
                        if (result = 0) then
                            ret = DisplayVideo(selectedVideo)
                            if (ret > 0) then
                                buttons = m.BuildButtons()
                                Exit For
                            end if
                        end if
                    end for
                else if (msg.GetIndex() = 2) then
                    m.ShowRelatedVideos(m.video)
                else if (msg.GetIndex() = 3) then
                    m.BrowseUserVideos(m.video.Author, m.video.UserID)
                else if (msg.GetIndex() = 4) then
                    m.BrowseUserPlaylists(m.video.Author, m.video.UserID)
                end if
            else if (msg.isRemoteKeyPressed()) then
                if (msg.GetIndex() = 4) then  ' left
                    if (videos.Count() > 1) then
                        idx = idx - 1
                        if ( idx < 0 ) then
                            ' Last video is the 'next' video link
                            idx = videos.Count() - 2
                        end if
                        m.video = videos[idx]
                        buttons = m.BuildButtons()
                        screen.SetContent( m.video )
                    end if
                else if (msg.GetIndex() = 5) then ' right
                    if (videos.Count() > 1) then
                        idx = idx + 1
                        if ( idx = videos.Count() - 1 ) then
                            ' Last video is the 'next' video link
                            idx = 0
                        end if
                        m.video = videos[idx]
                        buttons = m.BuildButtons()
                        screen.SetContent( m.video )
                    end if
                end if
            else
                'print "Unknown event: "; msg.GetType(); " msg: "; msg.GetMessage()
            end if
        else if (msg = invalid) then
            CheckForMCast()
        end If
    end while
End Sub

'********************************************************************
' Helper function to build the list of buttons on the springboard
' @return an roAssociativeArray of the buttons
'********************************************************************
Function BuildButtons_impl() as Object
    m.screen.ClearButtons()
    buttons = CreateObject("roAssociativeArray")
    resumeEnabled = false
    if (m.video.Live = false AND m.video.PlayStart > 0) then
        resumeEnabled = true
        buttons["resume"]         = m.screen.AddButton(0, "Resume")
        buttons["restart"]        = m.screen.AddButton(5, "Play from beginning")
    else
        buttons["play"]           = m.screen.AddButton(0, "Play")
    end if
    buttons["play_all"]     = m.screen.AddButton(1, "Play All")
    if (m.video.Author <> invalid) then
        ' Hide related videos if the Resume/Play from beginning options are enabled
        if (not(resumeEnabled)) then
            buttons["show_related"] = m.screen.AddButton(2, "Show Related Videos")
        end if
        buttons["more"]         = m.screen.AddButton(3, "More Videos By " + m.video.Author)
        buttons["playlists"]    = m.screen.AddButton(4, "Show "+ m.video.Author + "'s playlists")
    end if
    return buttons
End Function

'********************************************************************
' The video playback screen
'********************************************************************
Function DisplayVideo(content As Object)
    p = CreateObject("roMessagePort")
    video = CreateObject("roVideoScreen")
    video.setMessagePort(p)
    video.SetPositionNotificationPeriod(5)

    yt = LoadYouTube()

    ' Cache the video information for network sharing
    yt.activeVideo = content

    video.SetContent(content)
    video.show()

	yt.AddHistory(content)
    ret = -1
    while (true)
        msg = wait(0, video.GetMessagePort())
        if (type(msg) = "roVideoScreenEvent") then
            if (Instr(1, msg.getMessage(), "interrupted") > 0) then
                ret = 1
            end if
            if (msg.isScreenClosed()) then 'ScreenClosed event
                'print "Closing video screen"
                video.Close()
                exit while
            else if (msg.isRequestFailed()) then
                'print "play failed: "; msg.GetMessage()
            else if (msg.isPlaybackPosition()) then
                content["PlayStart"] = msg.GetIndex()
            else if (msg.isFullResult()) then
                content["PlayStart"] = 0
                ' The video has completed, zero out the cached version
                yt.activeVideo    = invalid
            else if (msg.isPartialResult()) then
                ' For plugin videos, the Length may not be available.
                if (content.Length <> invalid and content.PlayStart <> invalid) then
                    ' If we're within 30 seconds of the end of the video, don't allow resume
                    if (content.PlayStart > (content.Length - 30)) then
                        content["PlayStart"] = 0
                        ' The video has completed, zero out the cached version
                        yt.activeVideo    = invalid
                    end if
                end if
                ' Else if the length isn't valid, always allow resume
            else
                'print "Unknown event: "; msg.GetType(); " msg: "; msg.GetMessage()
            end if
        end if
    end while
    return ret
End Function

function getMP4Url(video as Object, timeout = 0 as integer, loginCookie = "" as string) as object
    video.Streams.Clear()
    if (Left(LCase(video.id), 4) = "http") then
        url = video.id
    else
        url = "http://www.youtube.com/get_video_info?hl=en&el=detailpage&video_id=" + video.id
    end if
    htmlString = ""
    port = CreateObject("roMessagePort")
    ut = CreateObject("roUrlTransfer")
    ut.SetPort(port)
    ut.AddHeader("User-Agent", "Mozilla/5.0 (compatible; MSIE 9.0; Windows NT 6.1; WOW64; Trident/5.0)")
    ut.AddHeader("Cookie", loginCookie)
    ut.SetUrl(url)
    if (ut.AsyncGetToString()) then
        while (true)
            msg = Wait(timeout, port)
            if (type(msg) = "roUrlEvent") then
                status = msg.GetResponseCode()
                if (status = 200) then
                    htmlString = msg.GetString()
                end if
                exit while
            else if (type(msg) = "Invalid") then
                ut.AsyncCancel()
                exit while
            end if
        end while
    end if
    urlEncodedFmtStreamMap = CreateObject("roRegex", "url_encoded_fmt_stream_map=([^(" + Chr(34) + "|&|$)]*)", "").Match(htmlString)
    if (urlEncodedFmtStreamMap.Count() > 1) then
        if (not(strTrim(urlEncodedFmtStreamMap[1]) = "")) then
            commaSplit = CreateObject("roRegex", "%2C", "").Split(urlEncodedFmtStreamMap [1])
            for each commaItem in commaSplit
                pair = {itag: "", url: "", sig: ""}
                ampersandSplit = CreateObject("roRegex", "%26", "").Split(commaItem)
                for each ampersandItem in ampersandSplit
                    equalsSplit = CreateObject("roRegex", "%3D", "").Split(ampersandItem)
                    if (equalsSplit.Count() = 2) then
                        pair[equalsSplit [0]] = equalsSplit [1]
                    end if
                end for
                if (pair.url <> "" and Left(LCase(pair.url), 4) = "http") then
                    if (pair.sig <> "") then
                        signature = "&signature=" + pair.sig
                    else
                        signature = ""
                    end if
                    urlDecoded = ut.Unescape(ut.Unescape(pair.url + signature))
                    ' print "urlDecoded: " ; urlDecoded
                    ' Determined from here: http://en.wikipedia.org/wiki/YouTube#Quality_and_codecs
                    if (pair.itag = "18") then
                        ' 18 is MP4 270p/360p H.264 at .5 Mbps video bitrate
                        video.Streams.Push({url: urlDecoded, bitrate: 512, quality: false, contentid: pair.itag})
                    else if (pair.itag = "22") then
                        ' 22 is MP4 720p H.264 at 2-2.9 Mbps video bitrate. I set the bitrate to the maximum, for best results.
                        video.Streams.Push({url: urlDecoded, bitrate: 2969, quality: true, contentid: pair.itag})
                    else if (pair.itag = "37") then
                        ' 37 is MP4 1080p H.264 at 3-5.9 Mbps video bitrate. I set the bitrate to the maximum, for best results.
                        video.Streams.Push({url: urlDecoded, bitrate: 6041, quality: true, contentid: pair.itag })
                    end if
                end if
            end for
            if (video.Streams.Count() > 0) then
                video.Live          = false
                video.StreamFormat  = "mp4"
                'video["PlayStart"] = 0
            end if
        else
            hlsUrl = CreateObject("roRegex", "hlsvp=([^(" + Chr(34) + "|&|$)]*)", "").Match(htmlString)
            if (urlEncodedFmtStreamMap.Count() > 1) then
                urlDecoded = ut.Unescape(ut.Unescape(ut.Unescape(hlsUrl[1])))
                'print "Found hlsVP: " ; urlDecoded
                video.Streams.Clear()
                video.Live              = true
                ' Set the PlayStart sufficiently large so it starts at 'Live' position
                video["PlayStart"]        = 500000
                video.StreamFormat      = "hls"
                'video.SwitchingStrategy = "unaligned-segments"
                video.SwitchingStrategy = "minimum-adaptation"
                video.Streams.Push({url: urlDecoded, bitrate: 0, quality: false, contentid: -1})
            end if

        end if
    else
        print ("Nothing in urlEncodedFmtStreamMap")
    end if
    return video.Streams
end function


Function video_get_qualities(video as Object) As Integer

    getMP4Url(video)
    if (video.Streams.Count() > 0) then
        return 0
    end if
    problem = ShowDialogNoButton("", "Having trouble finding a Roku-compatible stream...")
    sleep(3000)
    problem.Close()
    return -1
End Function

'********************************************************************
' Shows Users Video History
'********************************************************************
Sub show_history()
	videolist = CreateObject("roList")
	videosJSON = RegRead("videos", "history")
	if (videosJSON<>invalid) and (isnonemptystr(videosJSON)) then
		'print "videosJSON :" + videosJSON
        history = simpleJSONParser(videosJSON)
        if (islist(history) = true) then
			for each video in history
				v = m.GetVideoObject(video)
				if (v<>invalid) then
					videolist.Push(v)
				end if 
			end for
        end if
    end if

	m.DisplayVideoListFromMetadataList(videolist, "History", invalid, invalid, invalid)
End Sub

'********************************************************************
' Adds Video to History
' We only store selected properties to save Memory in Registry
'********************************************************************
Sub add_history(video as Object)
	videosJSON = RegRead("videos", "history")
	histObj = CreateObject("roAssociativeArray")

	' Try to save some memory with one char property names
	histObj["I"] = video.ID
	histObj["T"] = video.ShortDescriptionLine1

	saved = false
	if (videosJSON<>invalid) and (isnonemptystr(videosJSON)) then
		history = simpleJSONParser(videosJSON)
		if (islist(history) = true) then
			j = 0 
			k = -1
			for each v in history
				if v.i = histObj["I"] then
					k = j
				end if
				j = j + 1
			end for

			if k <> -1 then
				history.delete(k)
			end If

			history.Push(histObj)
			RegWrite("videos", SimpleJSONArray(history), "history")
			saved = true
		end if
	end if

	if (not(saved)) then
		history = CreateObject("roArray", 1, true)
		history.Push(histObj)
		RegWrite("videos", SimpleJSONArray(history), "history")
	end if
End Sub


Function get_video_details(theVideo as Object) As Object
	api = "videos/" + tostr(theVideo["ID"]) + "?v=2"
	xml = m.ExecServerAPI(api, invalid)["xml"]
	if (isxmlelement(xml)) then
		video = m.newVideoFromXML(xml)
		videos = CreateObject("roArray", 1, true)
		videos.Push(video)
		metadata = GetVideoMetaData(videos)
		if (metadata <> invalid AND metadata.Count() > 0) then
			metadata[0].["ID"] = theVideo["ID"]
			theVideo = metadata[0]
		end if
	end if
	return theVideo
End Function

'********************************************************************
' Builds Video Object based on History JSON Object
' TODO: This should be merged with GetVideoMetaData Function
'********************************************************************
Function get_video_object(video as Object) As Object
	meta = CreateObject("roAssociativeArray")
	meta.ContentType = "movie"
	meta["ID"]                     = video.I
	meta["Author"]                 = ""
	meta["TitleSeason"]            = ""
	meta["Title"]                  = ""
	meta["Actors"]                 = ""
	meta["Description"]            = ""
	meta["Categories"]             = ""
	meta["StarRating"]             = ""
	meta["ShortDescriptionLine1"]  = video.T 
	meta["ShortDescriptionLine2"]  = ""
	meta["SDPosterUrl"]            = "http://img.youtube.com/vi/" + tostr(video.I) + "/mqdefault.jpg"
	meta["HDPosterUrl"]            = meta["SDPosterUrl"]
	meta["Length"]                 = ""
	meta["xml"]                    = ""
	meta["UserID"]                 = ""
	meta["ReleaseDate"]            = ""
	meta["StreamFormat"]           = "mp4"
	meta["Live"]                   = false
	meta["Streams"]                = []
	meta["PlayStart"]              = 0
	meta["SwitchingStrategy"]      = "no-adaptation"
	meta["IsHistory"]				= true
	'meta.StreamBitrates=[]
	'meta.StreamQualities=[]
	'meta.StreamUrls=[]
	return meta
End Function