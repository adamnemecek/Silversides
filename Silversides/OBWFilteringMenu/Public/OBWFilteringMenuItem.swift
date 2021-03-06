/*===========================================================================
 OBWFilteringMenuItem.swift
 Silversides
 Copyright (c) 2016 Ken Heglund. All rights reserved.
 ===========================================================================*/

import Cocoa

/*==========================================================================*/

public class OBWFilteringMenuItem {
    
    // MARK: - OBWFilteringMenuItem public
    
    public init( title: String ) {
        self.title = title
    }
    
    // MARK: -
    
    public var title: String? = nil
    @NSCopying public var attributedTitle: NSAttributedString? = nil
    public var image: NSImage? = nil
    public var submenu: OBWFilteringMenu? = nil
    public var keyEquivalentModifierMask: NSEventModifierFlags = []
    
    public var enabled = true
    public var representedObject: AnyObject? = nil
    public var actionHandler: ( ( OBWFilteringMenuItem ) -> Void )? = nil
    
    public var titleOffset: NSSize {
        
        if OBWFilteringMenuItem.separatorItem === self {
            return NSZeroSize
        }
        
        return OBWFilteringMenuActionItemView.titleOffsetForMenuItem( self )
    }
    
    public var isSeparatorItem: Bool { return OBWFilteringMenuItem.separatorItem === self }
    public var isHighlighted: Bool { return self.menu?.highlightedItem === self }
    
    public var description: String {
        return "OBWFilteringMenuItem " + ( self.title ?? "" )
    }
    
    
    // MARK: -
    
    /*==========================================================================*/
    public static let separatorItem: OBWFilteringMenuItem = {
        return OBWFilteringMenuItem( title: "<separator>" )
    }()
    
    /*==========================================================================*/
    public func addAlternateItem( menuItem: OBWFilteringMenuItem ) throws {
        
        guard !self.isAlternate else {
            throw OBWFilteringMenuError.InvalidAlternateItem( message: "Alternate item cannot be added to an item that is itself an alternate" )
        }
        guard !self.isSeparatorItem else {
            throw OBWFilteringMenuError.InvalidAlternateItem( message: "A separator cannot be added as an alternate" )
        }
        
        let alternateModifierMask = menuItem.keyEquivalentModifierMask.intersect( OBWFilteringMenu.allowedModifierFlags )
        let hostModifierMask = self.keyEquivalentModifierMask
        
        guard alternateModifierMask != hostModifierMask else {
            throw OBWFilteringMenuError.InvalidAlternateItem( message: "Alternate modifier mask must be different than the mask of the item it is being added to" )
        }
        
        menuItem.menu = self.menu
        menuItem.isAlternate = true
        
        let key = OBWFilteringMenuItem.dictionaryKeyWithModifierMask( alternateModifierMask )
        
        if let itemToReplace = self.alternates[key] {
            itemToReplace.menu = nil
            itemToReplace.isAlternate = false
        }
        
        self.alternates[key] = menuItem
    }
    
    /*==========================================================================*/
    public func visibleItemForModifierFlags( modifierFlags: NSEventModifierFlags ) -> OBWFilteringMenuItem? {
        
        if modifierFlags == self.keyEquivalentModifierMask {
            return self
        }
        
        if self.isAlternate {
            return nil
        }
        
        if alternates.isEmpty && !self.keyEquivalentModifierMask.isEmpty {
            return nil
        }
        
        let key = OBWFilteringMenuItem.dictionaryKeyWithModifierMask( modifierFlags )
        return alternates[key] ?? self
    }
    
    /*==========================================================================*/
    public func performAction() {
        
        if let itemHandler = self.actionHandler {
            itemHandler( self )
        }
        else if let menuHandler = self.menu?.actionHandler {
            menuHandler( self )
        }
    }
    
    /*==========================================================================*/
    // MARK: - OBWFilteringMenuItem internal
    
    weak var menu: OBWFilteringMenu? = nil
    var canHighlight: Bool { return !self.isSeparatorItem }
    private(set) var alternates: [String:OBWFilteringMenuItem] = [:]
    private(set) var isAlternate: Bool = false
    
    var font: NSFont { return self.menu?.displayFont ?? NSFont.menuFontOfSize( 0.0 ) }
    
    /*==========================================================================*/
    // MARK: - OBWFilteringMenuItem private
    
    /*==========================================================================*/
    class func dictionaryKeyWithModifierMask( modifierMask: NSEventModifierFlags ) -> String {
        return String( format: "%lu", modifierMask.rawValue )
    }
}
