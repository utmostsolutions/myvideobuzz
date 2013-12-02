'******************************************************************************
' reddit.brs
' Adds support for handling reddit's json feed for subreddits
' Documentation on the API is here:
'             http://www.reddit.com/dev/api#section_listings
'******************************************************************************

'******************************************************************************
' Main function to begin displaying subreddit content
' @param youtube the current youtube instance
' @param url an optional URL with the multireddit to query, or the full link to parse. This is used when hitting the 'More Results' or 'Back' buttons on the video list page.
'     multireddits look like this: videos+funny+humor for /r/videos, /r/funny, and /r/humor
'******************************************************************************
Sub ViewReddits(youtube as Object, url = "videos" as String)
    screen = uitkPreShowPosterMenu("flat-episodic-16x9", "Reddit")
    screen.showMessage("Loading subreddits...")
    title = "Reddit"
    if (url = "videos") then
        tempSubs = RegRead("subreddits", "reddit")
        if (tempSubs <> invalid) then
            if (Len(tempSubs) > 0) then
                url = tempSubs
            end if
        end if
    end if
    response = QueryReddit(url)
    if (response.status = 403) then
        ShowErrorDialog(title + " may be private, or unavailable at this time. Try again.", "403 Forbidden")
        return
    end if
    if (response.status <> 200 OR response.json = invalid OR response.json.kind <> "Listing") then
        ShowConnectionFailed()
        return
    end if

    ' Everything is OK, display the list
    json = response.json
    videos = NewRedditVideoList(json.data.children)
    youtube.DisplayVideoListFromVideoList(videos, title, response.links, screen, invalid, GetRedditMetaData)
End Sub

'******************************************************************************
' Runs the query against the reddit servers, and handles parsing the response
' @param url an optional URL with the multireddit to query, or the full link to parse. This is used when hitting the 'More Results' or 'Back' buttons on the video list page.
'     multireddits look like this: videos+funny+humor for /r/videos, /r/funny, and /r/humor
' @return an roAssociativeArray containing the following members:
'               json = the JSON object represented as an roAssociativeArray
'               links = roArray of link objects containing the following members:
'                   func = callback function (ViewReddits)
'                   type = "next" or "previous"
'                   href = URL to the next or previous page of results
'               status = the HTTP status code response from the GET call
'******************************************************************************
Function QueryReddit(url = "videos" as String) As Object
    method = "GET"
    if (Instr(0, url, "http://")) then
        http = NewHttp(url)
    else
        http = NewHttp("http://www.reddit.com/r/" + url + "/hot.json")
    end if
    headers = { }

    http.method = method
    rsp = http.getToStringWithTimeout(10, headers)

    ' print "----------------------------------"
    ' print rsp
    ' print "----------------------------------"

    json = ParseJson(rsp)
    links = CreateObject("roArray", 1, true)
    if (json <> invalid) then
        if (json.data.after <> invalid) then
            link = CreateObject("roAssociativeArray")
            link.func = ViewReddits
            link.type = "next"
            http.RemoveParam("after", "urlParams")
            http.AddParam("after", json.data.after, "urlParams")
            link.href = http.GetURL()
            links.Push(link)
        end if
        if (json.data.before <> invalid) then
            link = CreateObject("roAssociativeArray")
            link.func = ViewReddits
            link.type = "previous"
            http.RemoveParam("before", "urlParams")
            http.AddParam("before", json.data.before, "urlParams")
            link.href = http.GetURL()
            links.Push(link)
        end if
    end if
    returnObj = CreateObject("roAssociativeArray")
    returnObj.json = json
    returnObj.links = links
    returnObj.status = http.status
    return returnObj
End Function

'******************************************************************************
' Creates an roList of video objects, determining if they are from YouTube AND the ID was properly parsed from the URL
' @param jsonObject the JSON object that was received in QueryReddit
' @return an roList of video objects that are from YouTube AND have a valid video ID associated
'******************************************************************************
Function NewRedditVideoList(jsonObject As Object) As Object
    videoList = CreateObject("roList")
    for each record in jsonObject
        domain = LCase(record.data.domain).Trim()
        if (domain = "youtube.com" OR domain = "youtu.be") then
            video = NewRedditVideo(record)
            if (video.GetID() <> invalid AND video.GetID() <> "") then
                videoList.Push(video)
            end if
        end if
    next
    return videoList
End Function

'******************************************************************************
' Creates a video roAssociativeArray, with the appropriate members needed to set Content Metadata and play a video with
' @param jsonObject the JSON "data" object that was received in QueryReddit, this is one result of many
' @return an roAssociativeArray of metadata for the current result
' TODO: There's no reason these are functions
'******************************************************************************
Function NewRedditVideo(jsonObject As Object) As Object
    video               = CreateObject("roAssociativeArray")
    ' video.youtube       = m
    video.json          = jsonObject
    video.GetID         = function()
        ' Regex found on the internets here: http://stackoverflow.com/questions/3452546/javascript-regex-how-to-get-youtube-video-id-from-url
        idMatches = CreateObject("roRegex", ".*(?:youtu.be\/|v\/|u\/\w\/|embed\/|watch\?v=)([^#\&\?]*).*", "").Match(m.json.data.url)
        id = invalid
        if (idMatches.Count() > 1) then
            id = idMatches[1]
        end if
        return id
    end function
    video.GetTitle      = function()
        return m.json.data.title
        title = m.json.data.url
        if (m.json.data.media <> invalid AND m.json.data.media.oembed <> invalid) then
            title = m.json.data.media.oembed.title
        end if
        return title
    end function
    video.GetCategory   = function(): return "/r/" + m.json.data.subreddit: end function
    video.GetDesc       = function()
        desc = ""
        if (m.json.data.media <> invalid AND m.json.data.media.oembed <> invalid) then
            desc = m.json.data.media.oembed.description
        end if
        return desc
    end function
    video.GetScore      = function(): return m.json.data.score : end function
    video.GetThumb      = function()
        thumb = ""
        if (m.json.data.media <> invalid AND m.json.data.media.oembed <> invalid) then
            thumb = m.json.data.media.oembed.thumbnail_url
        end if
        return thumb
    end function
    video.GetURL        = function()
        url = m.json.data.url
        if (m.json.data.media <> invalid AND m.json.data.media.oembed <> invalid) then
            url = m.json.data.media.oembed.url
        end if
        return url
    end function
    return video
End Function

'******************************************************************************
' Custom metadata function needed to simplify displaying of content metadata for reddit results.
' This is necessary since the amount of metadata available for videos is much less than that available
' when querying YouTube directly.
' This will be called from video.brs::DisplayVideoListFromVideoList
' It would be possible to Query YouTube for the additional metadata, but I don't know if that's worth it.
' @param videoList a list of video objects retrieved via the function NewRedditVideo
' @return an array of content metadata suitable for the Roku's screen objects.
'******************************************************************************
Function GetRedditMetaData(videoList As Object) as Object
    metadata = []

    for each video in videoList
        meta                           = CreateObject("roAssociativeArray")
        meta["ContentType"]            = "movie"
        meta["ID"]                     = video.GetID()
        meta["TitleSeason"]            = video.GetTitle()
        meta["Title"]                  = "Score: " + tostr(video.GetScore())
        meta["Actors"]                 = meta.Title
        meta["Description"]            = video.GetDesc()
        meta["Categories"]             = video.GetCategory()
        meta["ShortDescriptionLine1"]  = meta.TitleSeason
        meta["ShortDescriptionLine2"]  = meta.Title
        meta["SDPosterUrl"]            = video.GetThumb()
        meta["HDPosterUrl"]            = video.GetThumb()
        meta["StreamFormat"]           = "mp4"
        meta["Streams"]                = []
        metadata.Push(meta)
    end for

    return metadata
End Function

Sub EditRedditSettings()
    port = CreateObject("roMessagePort")
    screen = CreateObject("roSearchScreen")
    screen.SetMessagePort(port)

    history = CreateObject("roSearchHistory")
    subreddits = RegRead("subreddits", "reddit")
    if (RegRead("enabled", "reddit") = invalid) then
        if (subreddits <> invalid) then
            regex = CreateObject("roRegex", "\+", "") ' split on plus
            subredditArray = regex.Split(subreddits)
        else
            subredditArray = ["videos"]
        end if
    else
        subredditArray = []
    end if
    screen.SetSearchTerms(subredditArray)
    screen.SetBreadcrumbText("", "Hit the * button to remove a subreddit")
    screen.SetSearchTermHeaderText("Current Subreddits:")
    screen.SetClearButtonText("Remove All")
    screen.SetSearchButtonText("Add Subreddit")
    screen.SetEmptySearchTermsText("The reddit channel will be disabled")
    screen.Show()

    while (true)
        msg = wait(0, port)

        if (type(msg) = "roSearchScreenEvent") then
            'print "Event: "; msg.GetType(); " msg: "; msg.GetMessage()
            if (msg.isScreenClosed()) then
                exit while
            else if (msg.isPartialResult()) then
                ' Ignore it
            else if (msg.isFullResult()) then
                ' Check to see if they're trying to add a duplicate subreddit, or empty string
                newOne = msg.GetMessage()
                if (Len(newOne.Trim()) > 0) then
                    found = false
                    for each subreddit in subredditArray
                        if (LCase(subreddit).Trim() = LCase(newOne).Trim()) then
                            found = true
                            exit for
                        end if
                    next
                    if (not(found)) then
                        if (subredditArray.Count() = 0) then
                            subredditArray = []
                        end if
                        subredditArray.Push(newOne)

                        screen.SetSearchTerms(subredditArray)
                        RegDelete("enabled", "reddit")
                    end if
                end if
            else if (msg.isCleared()) then
                subredditArray.Clear()
                screen.ClearSearchTerms()
                RegWrite("enabled", "false", "reddit")
            else if ((msg.isRemoteKeyPressed() AND msg.GetIndex() = 10) OR msg.isButtonInfo()) then
                if (subredditArray.Count() > 0) then
                    subredditArray.Delete(msg.GetIndex())
                    screen.SetSearchTerms(subredditArray)
                end if
            'else
                'print("Unhandled event on search screen")
            end if
        'else
            'print("Unhandled msg type: " + type(msg))
        end if
    end while
    ' Save the user's subreddits when the settings screen is closing
    subString = ""
    if ( subredditArray.Count() > 0 ) then
        for i = 0 to subredditArray.Count() - 1
            subString = subString + subredditArray[i]
            if ( i < subredditArray.Count() - 1 ) then
                subString = subString + "+"
            end if
        next
        RegWrite("subreddits", subString, "reddit")
    else
        ' If their list is empty, just remove the unused registry key
        RegDelete("subreddits", "reddit")
    end if
End Sub