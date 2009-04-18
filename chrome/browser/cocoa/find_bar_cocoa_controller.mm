// Copyright (c) 2009 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import <Cocoa/Cocoa.h>

#include "base/mac_util.h"
#include "base/sys_string_conversions.h"
#include "grit/generated_resources.h"
#include "chrome/browser/find_bar_controller.h"
#include "chrome/browser/cocoa/browser_window_cocoa.h"
#import "chrome/browser/cocoa/find_bar_cocoa_controller.h"
#import "chrome/browser/cocoa/find_bar_bridge.h"
#import "chrome/browser/cocoa/tab_strip_controller.h"
#include "chrome/browser/tab_contents/web_contents.h"
#include "chrome/common/l10n_util.h"

@implementation FindBarCocoaController

- (id)initWithBrowserWindow:(BrowserWindowCocoa*)window {
  if ((self = [super initWithNibName:@"FindBar"
                              bundle:mac_util::MainAppBundle()])) {
    window->AddFindBar(self);
  }
  return self;
}

- (void)setFindBarBridge:(FindBarBridge*)findBarBridge {
  DCHECK(!findBarBridge_);  // should only be called once.
  findBarBridge_ = findBarBridge;
}

- (void)awakeFromNib {
  [[self view] setHidden:YES];
}

- (IBAction)close:(id)sender {
  if (findBarBridge_)
    findBarBridge_->GetFindBarController()->EndFindSession();
}

- (IBAction)previousResult:(id)sender {
  if (findBarBridge_)
    findBarBridge_->GetFindBarController()->web_contents()->StartFinding(
        base::SysNSStringToUTF16([findText_ stringValue]),
        false);
}

- (IBAction)nextResult:(id)sender {
  if (findBarBridge_)
    findBarBridge_->GetFindBarController()->web_contents()->StartFinding(
        base::SysNSStringToUTF16([findText_ stringValue]),
        true);
}

// Positions the find bar view in the correct location based on the
// current state of the window.  Currently only the visibility of the
// bookmark bar can affect the find bar's position.
- (void)positionFindBarView:(NSView*)contentArea {
  static const int kRightEdgeOffset = 25;
  NSView* findBarView = [self view];
  int findBarHeight = NSHeight([findBarView frame]);
  int findBarWidth = NSWidth([findBarView frame]);

  // Start by computing the upper right corner of the tab content
  // area, then move left by a constant offset and up one pixel.  This
  // gives us the upper right corner of our bounding box.  We move up
  // one pixel to overlap with the toolbar area, which allows us to
  // cover up the toolbar's border.
  NSRect windowRect = [contentArea frame];
  int max_x = NSMaxX(windowRect) - kRightEdgeOffset;
  int max_y = NSMaxY(windowRect) + 1;

  NSRect findRect = NSMakeRect(max_x - findBarWidth, max_y - findBarHeight,
                               findBarWidth, findBarHeight);
  [findBarView setFrame:findRect];
}

// NSControl delegate method.
- (void)controlTextDidChange:(NSNotification *)aNotification {
  if (!findBarBridge_)
    return;

  WebContents* web_contents =
      findBarBridge_->GetFindBarController()->web_contents();
  if (!web_contents)
    return;

  string16 findText = base::SysNSStringToUTF16([findText_ stringValue]);
  if (findText.length() > 0) {
    web_contents->StartFinding(findText, true);
  } else {
    // The textbox is empty so we reset.
    web_contents->StopFinding(true);  // true = clear selection on page.
    [self updateUIForFindResult:web_contents->find_result()
          withText:string16()];
  }
}

// Methods from FindBar
- (void)showFindBar {
  [[self view] setHidden:NO];
}

- (void)hideFindBar {
  [[self view] setHidden:YES];
}

- (void)setFocusAndSelection {
  [[findText_ window] makeFirstResponder:findText_];
}

- (void)setFindText:(const string16&)findText {
  [findText_ setStringValue:base::SysUTF16ToNSString(findText)];
}

- (void)clearResults:(const FindNotificationDetails&)results {
  [findText_ setStringValue:@""];
}

- (void)updateUIForFindResult:(const FindNotificationDetails&)result
                     withText:(const string16&)findText {
  // If we don't have any results and something was passed in, then
  // that means someone pressed Cmd-G while the Find box was
  // closed. In that case we need to repopulate the Find box with what
  // was passed in.
  if ([[findText_ stringValue] length] == 0 && !findText.empty()) {
    [findText_ setStringValue:base::SysUTF16ToNSString(findText)];
    [findText_ selectText:self];
  }

  // Make sure Find Next and Find Previous are enabled if we found any matches.
  BOOL buttonsEnabled = result.number_of_matches() > 0 ? YES : NO;
  [previousButton_ setEnabled:buttonsEnabled];
  [nextButton_ setEnabled:buttonsEnabled];

  // Update the results label.
  // TODO(rohitrao): The part of the webkit glue that computes match
  // ordinals is wrapped in OS_WIN.  Figure out why and remove it,
  // otherwise match counts won't work on Mac and Linux.
  NSString* searchString = [findText_ stringValue];
  if ([searchString length] > 0) {
    // TODO(rohitrao): Implement similar logic as in FindBarWin, to
    // avoid flickering when searching.  For now, only update the
    // results label if both our numbers are non-negative.
    if (result.active_match_ordinal() >= 0 && result.number_of_matches() >= 0) {
      [resultsLabel_ setStringValue:base::SysWideToNSString(
            l10n_util::GetStringF(IDS_FIND_IN_PAGE_COUNT,
                                  IntToWString(result.active_match_ordinal()),
                                  IntToWString(result.number_of_matches())))];
    }
  } else {
    // If there was no text entered, we don't show anything in the result count
    // area.
    [resultsLabel_ setStringValue:@""];
  }
}

- (BOOL)isFindBarVisible {
  return [[self view] isHidden] ? NO : YES;
}

@end