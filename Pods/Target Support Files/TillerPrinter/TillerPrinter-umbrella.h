#ifdef __OBJC__
#import <UIKit/UIKit.h>
#else
#ifndef FOUNDATION_EXPORT
#if defined(__cplusplus)
#define FOUNDATION_EXPORT extern "C"
#else
#define FOUNDATION_EXPORT extern
#endif
#endif
#endif

#import "ePOS2.h"
#import "ePOS2_PrinterS-Bridging-Header.h"
#import "ePOSEasySelect.h"
#import "TillerPrinter.h"

FOUNDATION_EXPORT double TillerPrinterVersionNumber;
FOUNDATION_EXPORT const unsigned char TillerPrinterVersionString[];

