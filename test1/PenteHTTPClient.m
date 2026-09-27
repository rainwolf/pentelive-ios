//
//  PenteHTTPClient.m
//

#import "PenteHTTPClient.h"

// Error domain and userInfo keys kept identical to the ones AFNetworking's
// AFHTTPResponseSerializer produced, so error objects look the same to callers.
static NSString *const PenteHTTPResponseErrorDomain =
    @"com.alamofire.error.serialization.response";
static NSString *const PenteHTTPFailingURLResponseErrorKey =
    @"com.alamofire.serialization.response.error.response";
static NSString *const PenteHTTPFailingURLResponseDataErrorKey =
    @"com.alamofire.serialization.response.error.data";

@implementation PenteHTTPClient

+ (NSURLSession *)sharedSession {
    static NSURLSession *session;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // Completion handlers run on the session's private background delegate
        // queue, so a semaphore wait on the main thread does not deadlock.
        session = [NSURLSession
            sessionWithConfiguration:NSURLSessionConfiguration.defaultSessionConfiguration];
    });
    return session;
}

// Mirrors AFHTTPResponseSerializer: for an HTTP response whose status code is
// outside 200-299, returns an error (the data is still passed through).
+ (nullable NSError *)validationErrorForResponse:(NSURLResponse *)response
                                            data:(NSData *)data {
    if (![response isKindOfClass:[NSHTTPURLResponse class]]) {
        return nil;
    }
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
    NSInteger statusCode = httpResponse.statusCode;
    if ((statusCode >= 200 && statusCode < 300) || !httpResponse.URL) {
        return nil;
    }
    NSMutableDictionary *userInfo = [@{
        NSLocalizedDescriptionKey :
            [NSString stringWithFormat:@"Request failed: %@ (%ld)",
                                       [NSHTTPURLResponse
                                           localizedStringForStatusCode:statusCode],
                                       (long)statusCode],
        NSURLErrorFailingURLErrorKey : httpResponse.URL,
        PenteHTTPFailingURLResponseErrorKey : httpResponse,
    } mutableCopy];
    if (data) {
        userInfo[PenteHTTPFailingURLResponseDataErrorKey] = data;
    }
    return [NSError errorWithDomain:PenteHTTPResponseErrorDomain
                               code:NSURLErrorBadServerResponse
                           userInfo:userInfo];
}

+ (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request
                                   completion:(void (^)(NSData *data,
                                                        NSURLResponse *response,
                                                        NSError *error))completion {
    return [[self sharedSession]
        dataTaskWithRequest:request
          completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err) {
              if (err) {
                  // As with AFNetworking: transport errors deliver no data.
                  completion(nil, resp, err);
                  return;
              }
              NSData *body = data ?: [NSData data];
              completion(body, resp,
                         [self validationErrorForResponse:resp data:body]);
          }];
}

+ (void)sendRequest:(NSURLRequest *)request
         completion:(void (^)(NSData *_Nullable data,
                              NSURLResponse *_Nullable response,
                              NSError *_Nullable error))completion {
    NSURLSessionDataTask *task =
        [self dataTaskWithRequest:request
                       completion:^(NSData *data, NSURLResponse *resp,
                                    NSError *err) {
                           dispatch_async(dispatch_get_main_queue(), ^{
                               if (completion) completion(data, resp, err);
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
        [self dataTaskWithRequest:request
                       completion:^(NSData *data, NSURLResponse *resp,
                                    NSError *err) {
                           urlResponse = resp;
                           responseData = data;
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
