//
//  PenteHTTPClient.m
//

#import "PenteHTTPClient.h"
@import AFNetworking;

@implementation PenteHTTPClient

+ (AFURLSessionManager *)sharedManager {
    static AFURLSessionManager *manager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[AFURLSessionManager alloc]
            initWithSessionConfiguration:NSURLSessionConfiguration.defaultSessionConfiguration];
        manager.responseSerializer = [AFHTTPResponseSerializer serializer];
        // Deliver completions on a background queue so a semaphore wait on the
        // main thread does not deadlock.
        manager.completionQueue =
            dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    });
    return manager;
}

+ (void)sendRequest:(NSURLRequest *)request
         completion:(void (^)(NSData *_Nullable data,
                              NSURLResponse *_Nullable response,
                              NSError *_Nullable error))completion {
    NSURLSessionDataTask *task =
        [[self sharedManager] dataTaskWithRequest:request
                                   uploadProgress:nil
                                 downloadProgress:nil
                                completionHandler:^(NSURLResponse *resp,
                                                    id responseObject,
                                                    NSError *err) {
                                    dispatch_async(dispatch_get_main_queue(), ^{
                                        if (completion) completion(responseObject, resp, err);
                                    });
                                }];
    [task resume];
}

+ (NSData *)sendSynchronousRequest:(NSURLRequest *)request
                 returningResponse:(NSURLResponse *__autoreleasing *)response
                             error:(NSError *__autoreleasing *)error {
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    __block NSData *responseData = nil;
    __block NSURLResponse *urlResponse = nil;
    __block NSError *requestError = nil;

    NSURLSessionDataTask *task =
        [[self sharedManager] dataTaskWithRequest:request
                                   uploadProgress:nil
                                 downloadProgress:nil
                                completionHandler:^(NSURLResponse *resp,
                                                    id responseObject,
                                                    NSError *err) {
                                    urlResponse = resp;
                                    responseData = responseObject;
                                    requestError = err;
                                    dispatch_semaphore_signal(semaphore);
                                }];
    [task resume];
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);

    if (response) *response = urlResponse;
    if (error) *error = requestError;
    return responseData;
}

@end
