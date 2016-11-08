//
//  AssetExport.m
//  gzjz_client
//
//  Created by 何耀 on 16/8/13.
//  Copyright © 2016年 Facebook. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AssetsLibrary/ALAssetsLibrary.h>
#import "AssetExport.h"
#import "SDAVAssetExportSession.h"
#import "RCTConvert.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import <AVFoundation/AVFoundation.h>
#import <Photos/Photos.h>


@implementation AssetExport : NSObject 

RCT_EXPORT_MODULE();

RCT_EXPORT_METHOD(exportVideo:(NSString *)path options:(NSDictionary *)options onResponse:(RCTResponseSenderBlock)onResponse)
{
  NSURL *uri = [NSURL fileURLWithPath:path isDirectory:NO];
  SDAVAssetExportSession *encoder = [SDAVAssetExportSession.alloc initWithAsset:[AVAsset assetWithURL:uri]];
  NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
  NSString *documentsDirectory = [paths objectAtIndex:0];
  NSString *myPathDocs =  [documentsDirectory stringByAppendingPathComponent:
                      [NSString stringWithFormat:@"lowerBitRate-%d.mp4",arc4random() % 1000]];
  NSURL *url = [NSURL fileURLWithPath:myPathDocs];
  encoder.outputURL=url;
  encoder.outputFileType = AVFileTypeMPEG4;
  encoder.shouldOptimizeForNetworkUse = YES;
  
  encoder.videoSettings = @
  {
  AVVideoCodecKey: AVVideoCodecH264,
  AVVideoWidthKey: [options objectForKey:@"width"],
  AVVideoHeightKey: [options objectForKey:@"height"],
  AVVideoCompressionPropertiesKey: @
    {
    AVVideoAverageBitRateKey: @2300000, // Lower bit rate here
    AVVideoProfileLevelKey: AVVideoProfileLevelH264High40,
    },
  };
  encoder.audioSettings = @
  {
  AVFormatIDKey: @(kAudioFormatMPEG4AAC),
  AVNumberOfChannelsKey: @2,
  AVSampleRateKey: @44100,
  AVEncoderBitRateKey: @128000,
  };
  
  [encoder exportAsynchronouslyWithCompletionHandler:^
   {
     int status = encoder.status;
     
     if (status == AVAssetExportSessionStatusCompleted)
     {
       AVAssetTrack *videoTrack = nil;
       AVURLAsset *asset = [AVAsset assetWithURL:encoder.outputURL];
       NSArray *videoTracks = [asset tracksWithMediaType:AVMediaTypeVideo];
       videoTrack = [videoTracks objectAtIndex:0];
       float frameRate = [videoTrack nominalFrameRate];
       float bps = [videoTrack estimatedDataRate];
       NSLog(@"Frame rate == %f",frameRate);
       NSLog(@"bps rate == %f",bps/(1024.0 * 1024.0));
       NSLog(@"Video export succeeded");
       // encoder.outputURL <- this is what you want!!
       onResponse(@[encoder.outputURL.absoluteString]);
     }
     else if (status == AVAssetExportSessionStatusCancelled)
     {
       NSLog(@"Video export cancelled");
     }
     else
     {
       NSLog(@"Video export failed with error: %@ (%ld)", encoder.error.localizedDescription, (long)encoder.error.code);
     }
   }];
}

RCT_EXPORT_METHOD(exportPhoto:(NSDictionary *)photo onResult:(RCTResponseSenderBlock)onResult){
  NSString *file = [photo objectForKey:@"file"];
  NSURL *url = [NSURL URLWithString:file];
  int maxWidth = [[photo objectForKey:@"maxWidth"] integerValue];
  int maxHeight = [[photo objectForKey:@"maxHeight"] integerValue];
  float quality = [[photo objectForKey:@"quality"] floatValue];
  ALAssetsLibrary* assetsLibrary = [[ALAssetsLibrary alloc] init];
  [assetsLibrary assetForURL:url resultBlock:^(ALAsset *asset) {
    ALAssetRepresentation *rep = [asset defaultRepresentation];
    Byte *buffer = (Byte*)malloc(rep.size);
    NSUInteger buffered = [rep getBytes:buffer fromOffset:0.0 length:rep.size error:nil];
    NSData *data = [NSData dataWithBytesNoCopy:buffer length:buffered freeWhenDone:YES];
    NSString *tempFileName = [[NSUUID UUID] UUIDString];
    NSString *fileName = [tempFileName stringByAppendingString:@".jpg"];
    NSString *path = [[NSTemporaryDirectory()stringByStandardizingPath] stringByAppendingPathComponent:fileName];
    UIImage *image = [UIImage imageWithData:data];
    image = [self fixOrientation:image];
    // If needed, downscale image
    image = [self downscaleImageIfNecessary:image maxWidth:maxWidth maxHeight:maxHeight];
    
    NSData *imgData;
    if ([[[photo objectForKey:@"imageFileType"] stringValue] isEqualToString:@"png"]) {
      imgData = UIImagePNGRepresentation(image);
    }
    else {
      imgData = UIImageJPEGRepresentation(image, quality);
    }
    [imgData writeToFile:path atomically:YES];
    onResult(@[path, [NSNumber numberWithInt:1]]);
  } failureBlock:^(NSError *error) {
    onResult(@[@"invalid assets path", [NSNumber numberWithInt:0]]);
  }];
}

- (UIImage*)downscaleImageIfNecessary:(UIImage*)image maxWidth:(float)maxWidth maxHeight:(float)maxHeight
{
  UIImage* newImage = image;
  
  // Nothing to do here
  if (image.size.width <= maxWidth && image.size.height <= maxHeight) {
    return newImage;
  }
  
  CGSize scaledSize = CGSizeMake(image.size.width, image.size.height);
  if (maxWidth < scaledSize.width) {
    scaledSize = CGSizeMake(maxWidth, (maxWidth / scaledSize.width) * scaledSize.height);
  }
  if (maxHeight < scaledSize.height) {
    scaledSize = CGSizeMake((maxHeight / scaledSize.height) * scaledSize.width, maxHeight);
  }
  
  // If the pixels are floats, it causes a white line in iOS8 and probably other versions too
  scaledSize.width = (int)scaledSize.width;
  scaledSize.height = (int)scaledSize.height;
  
  UIGraphicsBeginImageContext(scaledSize); // this will resize
  [image drawInRect:CGRectMake(0, 0, scaledSize.width, scaledSize.height)];
  newImage = UIGraphicsGetImageFromCurrentImageContext();
  if (newImage == nil) {
    NSLog(@"could not scale image");
  }
  UIGraphicsEndImageContext();
  
  return newImage;
}

- (UIImage *)fixOrientation:(UIImage *)srcImg {
  if (srcImg.imageOrientation == UIImageOrientationUp) {
    return srcImg;
  }
  
  CGAffineTransform transform = CGAffineTransformIdentity;
  switch (srcImg.imageOrientation) {
    case UIImageOrientationDown:
    case UIImageOrientationDownMirrored:
      transform = CGAffineTransformTranslate(transform, srcImg.size.width, srcImg.size.height);
      transform = CGAffineTransformRotate(transform, M_PI);
      break;
      
    case UIImageOrientationLeft:
    case UIImageOrientationLeftMirrored:
      transform = CGAffineTransformTranslate(transform, srcImg.size.width, 0);
      transform = CGAffineTransformRotate(transform, M_PI_2);
      break;
      
    case UIImageOrientationRight:
    case UIImageOrientationRightMirrored:
      transform = CGAffineTransformTranslate(transform, 0, srcImg.size.height);
      transform = CGAffineTransformRotate(transform, -M_PI_2);
      break;
    case UIImageOrientationUp:
    case UIImageOrientationUpMirrored:
      break;
  }
  
  switch (srcImg.imageOrientation) {
    case UIImageOrientationUpMirrored:
    case UIImageOrientationDownMirrored:
      transform = CGAffineTransformTranslate(transform, srcImg.size.width, 0);
      transform = CGAffineTransformScale(transform, -1, 1);
      break;
      
    case UIImageOrientationLeftMirrored:
    case UIImageOrientationRightMirrored:
      transform = CGAffineTransformTranslate(transform, srcImg.size.height, 0);
      transform = CGAffineTransformScale(transform, -1, 1);
      break;
    case UIImageOrientationUp:
    case UIImageOrientationDown:
    case UIImageOrientationLeft:
    case UIImageOrientationRight:
      break;
  }
  
  CGContextRef ctx = CGBitmapContextCreate(NULL, srcImg.size.width, srcImg.size.height, CGImageGetBitsPerComponent(srcImg.CGImage), 0, CGImageGetColorSpace(srcImg.CGImage), CGImageGetBitmapInfo(srcImg.CGImage));
  CGContextConcatCTM(ctx, transform);
  switch (srcImg.imageOrientation) {
    case UIImageOrientationLeft:
    case UIImageOrientationLeftMirrored:
    case UIImageOrientationRight:
    case UIImageOrientationRightMirrored:
      CGContextDrawImage(ctx, CGRectMake(0,0,srcImg.size.height,srcImg.size.width), srcImg.CGImage);
      break;
      
    default:
      CGContextDrawImage(ctx, CGRectMake(0,0,srcImg.size.width,srcImg.size.height), srcImg.CGImage);
      break;
  }
  
  CGImageRef cgimg = CGBitmapContextCreateImage(ctx);
  UIImage *img = [UIImage imageWithCGImage:cgimg];
  CGContextRelease(ctx);
  CGImageRelease(cgimg);
  return img;
}

@end