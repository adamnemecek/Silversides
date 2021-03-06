/*===========================================================================
 OBWFilteringMenuItemFilterStatus.swift
 Silversides
 Copyright (c) 2016 Ken Heglund. All rights reserved.
 ===========================================================================*/

import Cocoa

/*==========================================================================*/

private protocol FilterArgument {}
extension String: FilterArgument {}
extension NSRegularExpression: FilterArgument {}

/*==========================================================================*/

class OBWFilteringMenuItemFilterStatus {
    
    /*==========================================================================*/
    private init( menuItem: OBWFilteringMenuItem ) {
        
        self.menuItem = menuItem
        
        if let attributedTitle = menuItem.attributedTitle {
            self.searchableTitle = attributedTitle.string
            self.highlightedTitle = NSAttributedString( attributedString: attributedTitle )
        }
        else if let title = menuItem.title {
            
            self.searchableTitle = title
            
            let attributes = [ NSFontAttributeName : menuItem.font ]
            self.highlightedTitle = NSAttributedString( string: title, attributes: attributes )
        }
        else {
            self.searchableTitle = ""
            self.highlightedTitle = NSAttributedString()
        }
    }
    
    /*==========================================================================*/
    class func filterStatus( menu: OBWFilteringMenu, filterString: String ) -> [OBWFilteringMenuItemFilterStatus] {
        
        var statusArray: [OBWFilteringMenuItemFilterStatus] = []
        
        for menuItem in menu.itemArray {
            statusArray.append( OBWFilteringMenuItemFilterStatus.filterStatus( menuItem, filterString: filterString ) )
        }
        
        return statusArray
    }
    
    /*==========================================================================*/
    class func filterStatus( menuItem: OBWFilteringMenuItem, filterString: String ) -> OBWFilteringMenuItemFilterStatus {
        
        let status = OBWFilteringMenuItemFilterStatus( menuItem: menuItem )
        
        let bestScore = OBWFilteringMenuItemMatchCriteria.All.memberCount
        let worstScore = 0
        
        guard !filterString.isEmpty else {
            status.matchScore = bestScore
            return status
        }
        
        guard !menuItem.isSeparatorItem && !status.searchableTitle.isEmpty else {
            status.matchScore = worstScore
            return status
        }
        
        let filterFunction: ( OBWFilteringMenuItemFilterStatus, FilterArgument ) -> Int
        let filterArgument: FilterArgument
        
        if let regexPattern = OBWFilteringMenuItemFilterStatus.regexPatternFromString( filterString ) {
            filterFunction = OBWFilteringMenuItemFilterStatus.filter(_:withRegularExpression:)
            filterArgument = regexPattern
        }
        else {
            filterFunction = OBWFilteringMenuItemFilterStatus.filter(_:withString:)
            filterArgument = filterString
        }
        
        status.matchScore = filterFunction( status, filterArgument )
        
        for (_,alternateMenuItem) in menuItem.alternates {
            
            let alternateStatus = OBWFilteringMenuItemFilterStatus( menuItem: alternateMenuItem )
            alternateStatus.matchScore = filterFunction( alternateStatus, filterArgument )
            
            let modifierMask = alternateMenuItem.keyEquivalentModifierMask
            let key = OBWFilteringMenuItem.dictionaryKeyWithModifierMask( modifierMask )
            status.addAlternateStatus( alternateStatus, withKey: key )
        }
        
        return status
    }
    
    /*==========================================================================*/
    // MARK: - OBWFilteringMenuItemFilterStatus internal
    
    let menuItem: OBWFilteringMenuItem
    private(set) var highlightedTitle: NSAttributedString
    private(set) var matchScore = OBWFilteringMenuItemMatchCriteria.All.memberCount
    private(set) var alternateStatus: [String:OBWFilteringMenuItemFilterStatus]? = nil
    
    /*==========================================================================*/
    // MARK: - OBWFilteringMenuItemFilterStatus private
    
    private let searchableTitle: String
    
    /*==========================================================================*/
    private class func regexPatternFromString( filterString: String ) -> NSRegularExpression? {
        
        var pattern = filterString
        
        guard filterString.hasPrefix( "g/" ) else { return nil }
        guard filterString.hasSuffix( "/" ) else { return nil }
        guard !filterString.hasSuffix( "\\/" ) else { return nil }
        
        pattern = pattern.stringByReplacingOccurrencesOfString( "g/", withString: "", options: [ .AnchoredSearch ], range: nil )
        pattern = pattern.stringByReplacingOccurrencesOfString( "/", withString: "", options: [ .AnchoredSearch, .BackwardsSearch ], range: nil )
        
        if let regex = try? NSRegularExpression( pattern: pattern, options: .AnchorsMatchLines ) {
            return regex
        }
        
        return nil
    }
    
    /*==========================================================================*/
    private func addAlternateStatus( status: OBWFilteringMenuItemFilterStatus, withKey key: String ) {
        
        if self.alternateStatus == nil {
            self.alternateStatus = [key:status]
        }
        else {
            self.alternateStatus![key] = status
        }
    }
    
    /*==========================================================================*/
    private static var highlightAttributes: [String:AnyObject] = [
        NSBackgroundColorAttributeName : NSColor( deviceRed: 1.0, green: 1.0, blue: 0.0, alpha: 0.5 ),
        NSUnderlineStyleAttributeName : 1,
        NSUnderlineColorAttributeName : NSColor( deviceRed: 0.65, green: 0.50, blue: 0.0, alpha: 0.75 ),
    ]
    
    /*==========================================================================*/
    private class func filter( status: OBWFilteringMenuItemFilterStatus, withString filterArgument: FilterArgument ) -> Int {
        
        let worstScore = 0
        
        guard let filterString = filterArgument as? String else {
            preconditionFailure( "Expecting a String instance as the filterArgument" )
        }
        
        let searchableTitle = status.searchableTitle
        let workingHighlightedTitle = NSMutableAttributedString( attributedString: status.highlightedTitle )
        let highlightAttributes = OBWFilteringMenuItemFilterStatus.highlightAttributes
        
        var searchRange = searchableTitle.startIndex ..< searchableTitle.endIndex
        var matchMask = OBWFilteringMenuItemMatchCriteria.All
        var lastMatchIndex: String.Index? = nil
        
        for sourceIndex in filterString.startIndex ..< filterString.endIndex {
            
            guard !searchRange.isEmpty else { return worstScore }
            
            let filterSubstring = filterString.substringWithRange( sourceIndex ..< sourceIndex.successor() )
            
            guard let caseInsensitiveRange = searchableTitle.rangeOfString( filterSubstring, options: .CaseInsensitiveSearch, range: searchRange, locale: nil ) else { return worstScore }
            
            let caseSensitiveRange = searchableTitle.rangeOfString( filterSubstring, options: .LiteralSearch, range: searchRange, locale: nil )
            
            if caseSensitiveRange == nil || caseInsensitiveRange != caseSensitiveRange! {
                matchMask.remove( .CaseSensitive )
            }
            
            if let lastMatchIndex = lastMatchIndex {
                
                if caseInsensitiveRange.startIndex != lastMatchIndex.successor() {
                    matchMask.remove( .Contiguous )
                }
            }
            
            let highlightRange = NSRange(
                location: searchableTitle.startIndex.distanceTo( caseInsensitiveRange.startIndex ),
                length: 1
            )
            
            workingHighlightedTitle.addAttributes( highlightAttributes, range: highlightRange )
            
            lastMatchIndex = caseInsensitiveRange.startIndex
            searchRange.startIndex = caseInsensitiveRange.endIndex
        }
        
        status.highlightedTitle = NSAttributedString( attributedString: workingHighlightedTitle )
        
        return matchMask.memberCount
    }
    
    /*==========================================================================*/
    private class func filter( status: OBWFilteringMenuItemFilterStatus, withRegularExpression filterArgument: FilterArgument ) -> Int {
        
        let bestScore = OBWFilteringMenuItemMatchCriteria.All.memberCount
        let worstScore = 0
        
        guard let regex = filterArgument as? NSRegularExpression else {
            preconditionFailure( "expecting an NSRegularExpression instance as the filterArgument" )
        }
        
        let searchableTitle = status.searchableTitle
        let workingHighlightedTitle = NSMutableAttributedString( attributedString: status.highlightedTitle )
        let highlightAttributes = OBWFilteringMenuItemFilterStatus.highlightAttributes
        
        var matchScore = worstScore
        let matchingOptions = NSMatchingOptions.ReportCompletion
        let searchRange = NSRange( location: 0, length: searchableTitle.startIndex.distanceTo( searchableTitle.endIndex ) )
        
        regex.enumerateMatchesInString( searchableTitle, options: matchingOptions, range: searchRange) { ( result: NSTextCheckingResult?, flags: NSMatchingFlags, stop: UnsafeMutablePointer<ObjCBool> ) in
            
            guard !flags.contains( .InternalError ) else {
                stop.memory = true
                return
            }
            
            guard let result = result else { return }
            
            for rangeIndex in 0 ..< result.numberOfRanges {
                
                let resultRange = result.rangeAtIndex( rangeIndex )
                guard resultRange.location != NSNotFound else { continue }
                
                matchScore = bestScore
                
                workingHighlightedTitle.addAttributes( highlightAttributes, range: resultRange )
            }
        }
        
        status.highlightedTitle = NSAttributedString( attributedString: workingHighlightedTitle )
        
        return matchScore
    }
    
    /*==========================================================================*/
    // MARK: -
    
    /*==========================================================================*/
    private struct OBWFilteringMenuItemMatchCriteria: OptionSetType {
        
        init( rawValue: UInt ) {
            self.rawValue = rawValue & 0x7
        }
        
        private(set) var rawValue: UInt
        
        static let Basic            = OBWFilteringMenuItemMatchCriteria( rawValue: 1 << 0 )
        static let CaseSensitive    = OBWFilteringMenuItemMatchCriteria( rawValue: 1 << 1 )
        static let Contiguous       = OBWFilteringMenuItemMatchCriteria( rawValue: 1 << 2 )
        
        static let All = OBWFilteringMenuItemMatchCriteria( rawValue: 0x7 )
        static let Last = OBWFilteringMenuItemMatchCriteria.Contiguous
        
        var memberCount: Int {
            
            let rawValue = self.rawValue
            var bitMask = OBWFilteringMenuItemMatchCriteria.Last.rawValue
            var bitCount = 0
            repeat {
                
                if ( bitMask & rawValue ) != 0 {
                    bitCount += 1
                }
                
                bitMask >>= 1
                
            } while bitMask != 0
            
            return bitCount
        }
    }
    
}
