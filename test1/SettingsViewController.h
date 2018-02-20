//
//  SettingsViewController.h
//  test1
//
//  Created by rainwolf on 28/12/12.
//  Copyright (c) 2012 Triade. All rights reserved.
//

#import "IASKAppSettingsViewController.h"
#import "PenteNavigationViewController.h"
#import "PopoverView.h"
#import "ICDMaterialActivityIndicatorView.h"

@interface SettingsViewController : IASKAppSettingsViewController <IASKSettingsDelegate, MFMailComposeViewControllerDelegate, UIImagePickerControllerDelegate, PopoverViewDelegate> {
    NSString *username, *password;
    PopoverView *popoverView;
    ICDMaterialActivityIndicatorView *progressView;
    PenteNavigationViewController *navC;
    BOOL showAIOption;
}
@property(nonatomic,retain) NSString *username;
@property(nonatomic,retain) NSString *password;
@property(nonatomic,retain) PopoverView *popoverView;
@property(nonatomic,retain) PenteNavigationViewController *navC;
@property (strong,nonatomic) ICDMaterialActivityIndicatorView *progressView;
@property(atomic, assign) BOOL showAIOption;

//-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath;

- (id)initWithFile:(NSString*)file specifier:(IASKSpecifier*)specifier;

@end
