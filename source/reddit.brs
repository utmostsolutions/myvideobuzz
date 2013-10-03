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
' TODO: Need to support user-customized subreddits.
'******************************************************************************
Sub ViewReddits(youtube as Object, url = "videos" as String)
    screen = uitkPreShowPosterMenu("flat-episodic-16x9", "Reddit")
    screen.showMessage("Loading subreddits...")
    title = "Reddit"
    response = QueryReddit(url)
    if (response.status = 403) then
        ShowErrorDialog(title + " may be private, or unavailable at this time. Try again.", "403 Forbidden")
        return
    end if
    if (response.status <> 200 OR response.json.kind <> "Listing") then
        ShowConnectionFailed()
        return
    end if

    ' Everything is OK, display the list
    json = response.json
    videos = NewRedditVideoList(json.data.children)
    youtube.DisplayVideoList(videos, title, response.links, screen, invalid, GetRedditMetaData)
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
        domain = record.data.domain
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
' This will be called from video.brs::DisplayVideoList
' It would be possible to Query YouTube for the additional metadata, but I don't know if that's worth it.
' @param videoList a list of video objects retrieved via the function NewRedditVideo
' @return an array of content metadata suitable for the Roku's screen objects.
'******************************************************************************
Function GetRedditMetaData(videoList As Object) as Object
    metadata = []

    for each video in videoList
        meta                        = CreateObject("roAssociativeArray")
        meta.ContentType            = "movie"
        meta.ID                     = video.GetID()
        meta.TitleSeason            = video.GetTitle()
        meta.Title                  = "Score: " + tostr(video.GetScore())
        meta.Actors                 = meta.Title
        meta.Description            = video.GetDesc()
        meta.Categories             = video.GetCategory()
        meta.ShortDescriptionLine1  = meta.TitleSeason
        meta.ShortDescriptionLine2  = meta.Title
        meta.SDPosterUrl            = video.GetThumb()
        meta.HDPosterUrl            = video.GetThumb()
        meta.StreamFormat           = "mp4"
        meta.Streams                = []
        metadata.Push(meta)
    end for

    return metadata
End Function
