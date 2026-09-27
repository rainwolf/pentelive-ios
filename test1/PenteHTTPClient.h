//
//  PenteHTTPClient.h
//
//  Drop-in replacement for NSURLConnection sendSynchronousRequest:returningResponse:error:
//  backed by NSURLSession.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface PenteHTTPClient : NSObject

/// Asynchronous HTTP request via NSURLSession. Completion is called on the main queue.
+ (void)sendRequest:(NSURLRequest *)request
         completion:(void (^)(NSData *_Nullable data,
                              NSURLResponse *_Nullable response,
                              NSError *_Nullable error))completion;

/// Synchronous HTTP request via NSURLSession (deprecated — use sendRequest:completion: instead).
+ (nullable NSData *)sendSynchronousRequest:(NSURLRequest *)request
                          returningResponse:(NSURLResponse *_Nullable __autoreleasing *_Nullable)response
                                      error:(NSError *_Nullable __autoreleasing *_Nullable)error;

@end

NS_ASSUME_NONNULL_END
