'********************************************************************
' YouTube Search
'********************************************************************
Sub youtube_search()
    port = CreateObject("roMessagePort")
    screen = CreateObject("roSearchScreen")
    screen.SetMessagePort(port)

    history = CreateObject("roSearchHistory")
    screen.SetSearchTerms(history.GetAsArray())
    screen.SetBreadcrumbText("", "Hit the * button for search options")
    screen.Show()

    while (true)
        msg = wait(0, port)

        if (type(msg) = "roSearchScreenEvent") then
            'print "Event: "; msg.GetType(); " msg: "; msg.GetMessage()
            if (msg.isScreenClosed()) then
                return
            else if (msg.isPartialResult()) then
                screen.SetSearchTermHeaderText("Suggestions:")
                screen.SetClearButtonEnabled(false)
                screen.SetSearchTerms(GenerateSearchSuggestions(msg.GetMessage()))
            else if (msg.isFullResult()) then
                keyword = msg.GetMessage()
                query = "videos?q=" + keyword
                prompt = "Searching YouTube for " + Quote() + keyword + Quote()
                if (m.searchLengthFilter <> "") then
                    query = query + "&duration=" + LCase(m.searchLengthFilter)
                    prompt = prompt + Chr(10) + "Length: " + m.searchLengthFilter
                end if
                if (m.searchDateFilter <> "") then
                    query = query + "&time=" + strReplace(LCase(m.searchDateFilter), " ", "_")
                    prompt = prompt + Chr(10) + "Timeframe: " + m.searchDateFilter
                end if
                if (m.searchSort <> "") then
                    query = query + "&orderby=" + m.searchSort
                    prompt = prompt + Chr(10) + "Sort: " + GetSortText(m.searchSort)
                end if
                dialog = ShowPleaseWait("Please wait", prompt)
                xml = m.ExecServerAPI(query, invalid)["xml"]
                if (not(isxmlelement(xml))) then
                    dialog.Close()
                    ShowConnectionFailed()
                    return
                end if
                videos = m.newVideoListFromXML(xml.entry)
                if (videos.Count() > 0) then
                    history.Push(keyword)
                    screen.AddSearchTerm(keyword)
                    dialog.Close()
                    m.DisplayVideoList(videos, "Search Results for " + Chr(39) + keyword + Chr(39), xml.link, invalid, invalid)
                else
                    dialog.Close()
                    ShowErrorDialog("No videos match your search", "Search results")
                end if
            else if (msg.isCleared()) then
                history.Clear()
            else if ((msg.isRemoteKeyPressed() AND msg.GetIndex() = 10) OR msg.isButtonInfo()) then
                while (SearchOptionDialog() = 1)
                end while
            'else
                'print("Unhandled event on search screen")
            end if
        'else
            'print("Unhandled msg type: " + type(msg))
        end if
    end while
End Sub


Function GenerateSearchSuggestions(partSearchText As String) As Object
    suggestions = CreateObject("roArray", 1, true)
    length = len(partSearchText)
    if (length > 0) then
        searchRequest = CreateObject("roUrlTransfer")
        searchRequest.SetURL("http://suggestqueries.google.com/complete/search?hl=en&client=youtube&hjson=t&ds=yt&jsonp=window.yt.www.suggest.handleResponse&q=" + URLEncode(partSearchText))
        jsonAsString = searchRequest.GetToString()
        jsonAsString = strReplace(jsonAsString,"window.yt.www.suggest.handleResponse(","")
        jsonAsString = Left(jsonAsString, Len(jsonAsString) -1)
        response = simpleJSONParser(jsonAsString)

        if (islist(response) = true) then
            if (response.Count() > 1) then
                for each sugg in response[1]
                        suggestions.Push(sugg[0])
                end for
            end if
        end if

    else
        history = CreateObject("roSearchHistory")
        suggestions = history.GetAsArray()
    end if
    return suggestions
End Function

Function SearchOptionDialog() as Integer
    dialog = CreateObject("roMessageDialog")
    port = CreateObject("roMessagePort")
    dialog.SetMessagePort(port)
    dialog.SetTitle("Search Settings")
    updateSearchDialogText(dialog)
    dialog.EnableBackButton(true)
    dialog.addButton(1, "Change Length Filter")
    dialog.addButton(2, "Change Time Filter")
    dialog.addButton(3, "Change Sort Setting")
    dialog.addButton(4, "Done")
    dialog.Show()
    while true
        dlgMsg = wait(0, dialog.GetMessagePort())
        if (type(dlgMsg) = "roMessageDialogEvent") then
            if (dlgMsg.isButtonPressed()) then
                if (dlgMsg.GetIndex() = 1) then
                    dialog.Close()
                    ret = SearchFilterClicked()
                    if (ret <> "ignore") then
                        m.youtube.searchLengthFilter = ret
                        if (ret <> "") then
                            RegWrite("length", ret, "Search")
                        else
                            RegDelete("length", "Search")
                        end if
                        updateSearchDialogText(dialog, true)
                    end if
                    return 1 ' Re-open the options
                else if (dlgMsg.GetIndex() = 2) then
                    dialog.Close()
                    ret = SearchDateClicked()
                    if (ret <> "ignore") then
                        m.youtube.searchDateFilter = ret
                        if (ret <> "") then
                            RegWrite("date", ret, "Search")
                        else
                            RegDelete("date", "Search")
                        end if
                        updateSearchDialogText(dialog, true)
                    end if
                    return 1 ' Re-open the options
                else if (dlgMsg.GetIndex() = 3) then
                    dialog.Close()
                    ret = SearchSortClicked()
                    if (ret <> "ignore") then
                        m.youtube.searchSort = ret
                        if (ret <> "") then
                            RegWrite("sort", ret, "Search")
                        else
                            RegDelete("sort", "Search")
                        end if
                        updateSearchDialogText(dialog, true)
                    end if
                    return 1 ' Re-open the options
                else if (dlgMsg.GetIndex() = 4) then
                    dialog.Close()
                    exit while
                end if
            else if (dlgMsg.isScreenClosed()) then
                dialog.Close()
                exit while
            else
                ' print ("Unhandled msg type")
                exit while
            end if
        else
            ' print ("Unhandled msg: " + type(dlgMsg))
            exit while
        end if
    end while
    ' print ("Exiting search option dialog")
    return 0
End Function

Sub updateSearchDialogText(dialog as Object, isUpdate = false as Boolean)
    searchLengthText = "None"
    searchDateText = "None"
    searchSortText = "None"
    if (m.youtube.searchLengthFilter <> "") then
        searchLengthText = m.youtube.searchLengthFilter
    end if
    if (m.youtube.searchDateFilter <> "") then
        searchDateText = m.youtube.searchDateFilter
    end if
    if (m.youtube.searchSort <> "") then
        searchSortText = GetSortText(m.youtube.searchSort)
    end if
    dialogText = "Length: " + searchLengthText + chr(10) + "Timeframe: " + searchDateText + chr(10) + "Sort: " + searchSortText
    if (isUpdate = true) then
        dialog.UpdateText(dialogText)
    else
        dialog.SetText(dialogText)
    end if
End Sub

Function SearchFilterClicked() as String
    dialog = CreateObject("roMessageDialog")
    port = CreateObject("roMessagePort")
    dialog.SetMessagePort(port)
    dialog.SetTitle("Length Filter")
    dialog.EnableBackButton(true)
    dialog.addButton(1, "None")
    dialog.addButton(2, "Short (<4 minutes)")
    dialog.addButton(3, "Medium (>=4 and <=20 minutes)")
    dialog.addButton(4, "Long (>20 minutes)")
    if (m.youtube.searchLengthFilter = "Short") then
        dialog.SetFocusedMenuItem(1)
    else if (m.youtube.searchLengthFilter = "Medium") then
        dialog.SetFocusedMenuItem(2)
    else if (m.youtube.searchLengthFilter = "Long") then
        dialog.SetFocusedMenuItem(3)
    end if
    dialog.Show()
    retVal = "ignore"
    while true
        dlgMsg = wait(0, dialog.GetMessagePort())
        if (type(dlgMsg) = "roMessageDialogEvent") then
            if (dlgMsg.isButtonPressed()) then
                if (dlgMsg.GetIndex() = 1) then
                    retVal = ""
                else if (dlgMsg.GetIndex() = 2) then
                    retVal = "Short"
                else if (dlgMsg.GetIndex() = 3) then
                    retVal = "Medium"
                else if (dlgMsg.GetIndex() = 4) then
                    retVal = "Long"
                end if
                exit while
            else if (dlgMsg.isScreenClosed()) then
                exit while
            end if
        end if
    end while
    dialog.Close()
    ' print ("Exiting SearchFilterClicked")
    return retVal
End Function

Function SearchDateClicked() as String
    dialog = CreateObject("roMessageDialog")
    port = CreateObject("roMessagePort")
    dialog.SetMessagePort(port)
    dialog.SetTitle("Timeframe Filter")
    dialog.EnableBackButton(true)
    dialog.addButton(1, "None")
    dialog.addButton(2, "Today")
    dialog.addButton(3, "This Week")
    dialog.addButton(4, "This Month")
    if (m.youtube.searchDateFilter = "Today") then
        dialog.SetFocusedMenuItem(1)
    else if (m.youtube.searchDateFilter = "This Week") then
        dialog.SetFocusedMenuItem(2)
    else if (m.youtube.searchDateFilter = "This Month") then
        dialog.SetFocusedMenuItem(3)
    end if
    dialog.Show()
    retVal = "ignore"
    while true
        dlgMsg = wait(0, dialog.GetMessagePort())
        if (type(dlgMsg) = "roMessageDialogEvent") then
            if (dlgMsg.isButtonPressed()) then
                if (dlgMsg.GetIndex() = 1) then
                    retVal = ""
                else if (dlgMsg.GetIndex() = 2) then
                    retVal = "Today"
                else if (dlgMsg.GetIndex() = 3) then
                    retVal = "This Week"
                else if (dlgMsg.GetIndex() = 4) then
                    retVal = "This Month"
                end if
                exit while
            else if (dlgMsg.isScreenClosed()) then
                exit while
            end if
        end if
    end while
    dialog.Close()
    ' print ("Exiting SearchDateClicked")
    return retVal
End Function

Function SearchSortClicked() as String
    dialog = CreateObject("roMessageDialog")
    port = CreateObject("roMessagePort")
    dialog.SetMessagePort(port)
    dialog.SetTitle("Sort Options")
    dialog.EnableBackButton(true)
    dialog.addButton(1, "None")
    dialog.addButton(2, "Newest First")
    dialog.addButton(3, "Views (most to least)")
    dialog.addButton(4, "Rating (highest to lowest)")
    if (m.youtube.searchSort = "published") then
        dialog.SetFocusedMenuItem(1)
    else if (m.youtube.searchSort = "viewCount") then
        dialog.SetFocusedMenuItem(2)
    else if (m.youtube.searchSort = "rating") then
        dialog.SetFocusedMenuItem(3)
    end if
    dialog.Show()
    retVal = "ignore"
    while true
        dlgMsg = wait(0, dialog.GetMessagePort())
        if (type(dlgMsg) = "roMessageDialogEvent") then
            if (dlgMsg.isButtonPressed()) then
                if (dlgMsg.GetIndex() = 1) then
                    retVal = ""
                else if (dlgMsg.GetIndex() = 2) then
                    retVal = "published"
                else if (dlgMsg.GetIndex() = 3) then
                    retVal = "viewCount"
                else if (dlgMsg.GetIndex() = 4) then
                    retVal = "rating"
                end if
                exit while
            else if (dlgMsg.isScreenClosed()) then
                exit while
            end if
        end if
    end while
    dialog.Close()
    ' print ("Exiting SearchSortClicked")
    return retVal
End Function

Function GetSortText(internalValue as String) as String
    retVal = "None"
    if (m.youtube.searchSort = "published") then
        retVal = "Newest First"
    else if (m.youtube.searchSort = "viewCount") then
        retVal = "Views"
    else if (m.youtube.searchSort = "rating") then
        retVal = "Rating"
    end if
    return retVal
End Function