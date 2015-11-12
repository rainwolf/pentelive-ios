//
//  SettingsViewController.h
//  test1
//
//  Created by rainwolf on 28/12/12.
//  Copyright (c) 2012 Triade. All rights reserved.
//

#import "IASKAppSettingsViewController.h"
#import "PenteNavigationViewController.h"

@interface SettingsViewController : IASKAppSettingsViewController <IASKSettingsDelegate, MFMailComposeViewControllerDelegate> {
    NSString *username, *password;
}
@property(nonatomic,retain) NSString *username;
@property(nonatomic,retain) NSString *password;

//-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath;


@end
