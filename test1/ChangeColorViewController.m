//
//  ChangeColorViewController.m
//  penteLive
//
//  Created by rainwolf on 15/07/16.
//  Copyright © 2016 Triade. All rights reserved.
//

#import "ChangeColorViewController.h"
#import "HRColorPickerView.h"
#import "HRColorMapView.h"
#import "HRBrightnessSlider.h"
#import "UIColor+hex.h"
#import "PenteNavigationViewController.h"

@implementation ChangeColorViewController {
    HRColorPickerView *colorPickerView;
    UIColor *_color;
}

- (id)initWithColor:(UIColor *)defaultColor {
    self = [super init];
    if (self) {
        _color = defaultColor;
    }
    return self;
}

-(void)viewDidLoad {
    [super viewDidLoad];
//    self.view = [[UIView alloc] init];
    self.view.autoresizingMask = UIViewAutoresizingFlexibleHeight;
    self.edgesForExtendedLayout = UIRectEdgeNone;
    self.view.backgroundColor = [UIColor whiteColor];
    
    colorPickerView = [[HRColorPickerView alloc] init];
    colorPickerView.frame = self.view.frame;
    colorPickerView.autoresizingMask = UIViewAutoresizingFlexibleHeight;
    colorPickerView.color = _color;
    
    HRColorMapView *colorMapView = [[HRColorMapView alloc] init];
    colorMapView.saturationUpperLimit = @1;
    colorMapView.tileSize = @1;
    [colorPickerView addSubview:colorMapView];
    colorPickerView.colorMapView = colorMapView;
    
    HRBrightnessSlider *slider = [[HRBrightnessSlider alloc] init];
    slider.brightnessLowerLimit = @0;
    [colorPickerView addSubview:slider];
    colorPickerView.brightnessSlider = slider;
    //    Please uncomment. If you want to catch the color change event.
    //    [colorPickerView addTarget:self
    //                        action:@selector(colorWasChanged:)
    //              forControlEvents:UIControlEventValueChanged];
    
    [self.view addSubview:colorPickerView];
    [self.navigationController.navigationBar setTranslucent:YES];
}

-(void)viewWillDisappear:(BOOL)animated {
    NSString *post = [NSString stringWithFormat:@"changeNameColor=%@", [[colorPickerView.color cssString] substringFromIndex:1]];
    NSData *postData = [post dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
    NSString *postLength = [NSString stringWithFormat:@"%lu", (unsigned long)[postData length]];
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    [request setURL:[NSURL URLWithString:@"https://www.pente.org/gameServer/changeColor"]];
    //        [request setURL:[NSURL URLWithString:@"https://development.pente.org/gameServer/tb/newGame"]];
    [request setHTTPMethod:@"POST"];
    [request setValue:postLength forHTTPHeaderField:@"Content-Length"];
    [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    [request setHTTPBody:postData];
    [request setTimeoutInterval:7.0];
    NSURLResponse *response;
    NSError *error;
    [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    if (error == nil) {
        ((PenteNavigationViewController *) self.navigationController).player.myColor = colorPickerView.color;
    }
    if (error) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:[NSString stringWithFormat:@"Reason: %@", error.localizedDescription] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        //        [alert show];
        [alert performSelectorOnMainThread:@selector(show) withObject:nil waitUntilDone:YES];
        return;
    }
    [super viewWillDisappear:animated];
}

@end
