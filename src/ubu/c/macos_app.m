#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#import <Cocoa/Cocoa.h>
#import <Foundation/Foundation.h>

#define UBU_MAC_USE_OPENGL 1

#if defined(UBU_MAC_USE_OPENGL)
#import <OpenGL/OpenGL.h>
#import <OpenGL/gl3.h>
#endif

#include "common.h"

@interface UbuMacApplicationDelegate : NSObject<NSApplicationDelegate>
- (void)applicationDidFinishLaunching:(NSNotification *)notification;
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *) sender;
@end

@interface UbuMacWindowDelegate : NSObject<NSWindowDelegate>
@end

#if defined(UBU_MAC_USE_OPENGL)
@interface UbuMacView : NSOpenGLView {
    CVDisplayLinkRef display_link;
}
- (void)prepareOpenGL;
- (CVReturn) getFrameForTime:(const CVTimeStamp *)outputTime;
- (void)dealloc;
@end
#elif
@interface UbuMacView
@end
#endif


enum UbuMacErrorCode {
    UBU_MAC_OK,
    UBU_MAC_ALLOC_WINDOW_ERROR,
    UBU_MAC_ALLOC_WINDOW_DELEGATE_ERROR,
    UBU_MAC_GL_PIXEL_FORMAT_ERROR,
    UBU_MAC_GL_VIEW_INIT_ERROR,
};

typedef struct {
    int width;
    int height;
    const char *title;
    ubu_bool_t centered;
    void (*init_fn)(int error_code);
    void (*frame_fn)();
} UbuMacAppDesc;

typedef struct {
    UbuMacApplicationDelegate *app_dlg;
    NSWindow *window;
    UbuMacWindowDelegate *win_dlg;
    UbuMacView *view;
    UbuMacAppDesc desc;
    int frame_count;
} UbuMacAppState;

static UbuMacAppState state;

@implementation UbuMacApplicationDelegate
- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    NSLog(@"applicationDidFinishLaunching");

    int width = state.desc.width == 0 ? 800 : state.desc.width;
    int height = state.desc.height == 0 ? 800 : state.desc.height;

    NSRect content_rect = NSMakeRect(0, 0, width, height);
    NSUInteger style_mask = NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable;

    NSWindow *win = [[NSWindow alloc] initWithContentRect:content_rect 
                                                styleMask:style_mask 
                                                  backing:NSBackingStoreBuffered 
                                                    defer:NO];

    if (!win) {
        state.desc.init_fn(UBU_MAC_ALLOC_WINDOW_ERROR);
    }

    UbuMacWindowDelegate  *win_dlg = [[UbuMacWindowDelegate alloc] init];

    if (!win_dlg) {
        state.desc.init_fn(UBU_MAC_ALLOC_WINDOW_DELEGATE_ERROR);
    }

    [win setDelegate:win_dlg];
    NSString *title = state.desc.title == 0 ? @"UBU" :  [NSString stringWithUTF8String:state.desc.title];
    [win setTitle: title];
    [win setAcceptsMouseMovedEvents:YES];
    [win setRestorable:NO];

    if (state.desc.centered) {
        [win center];
    }
    
    [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
    [win orderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
    [win makeKeyAndOrderFront:nil];
    
    state.window = win;
    state.win_dlg = win_dlg;
 
#if defined(UBU_MAC_USE_OPENGL)
    NSOpenGLPixelFormatAttribute glpfattr[] = {
        NSOpenGLPFAAccelerated,   
        NSOpenGLPFADoubleBuffer, 
        NSOpenGLPFAOpenGLProfile, NSOpenGLProfileVersion3_2Core,
        NSOpenGLPFAColorSize,     24,
        NSOpenGLPFAAlphaSize,     8,
        NSOpenGLPFADepthSize,     24,
        NSOpenGLPFAStencilSize,   8,
        NSOpenGLPFASampleBuffers, 0,
        0,
    };

    NSOpenGLPixelFormat *gl_pixel_format = [[NSOpenGLPixelFormat alloc] initWithAttributes:glpfattr];

    if (!gl_pixel_format) {
        state.desc.init_fn(UBU_MAC_GL_PIXEL_FORMAT_ERROR);
    }

    UbuMacView *view = [[UbuMacView alloc] initWithFrame:content_rect pixelFormat:gl_pixel_format];

    if (!view) {
        state.desc.init_fn(UBU_MAC_GL_VIEW_INIT_ERROR);
    }
#else
#endif
   
    state.view = view;
    
    [state.window setContentView:view];
    [state.window makeFirstResponder:view];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *) sender {
    return true;
}
@end

@implementation UbuMacWindowDelegate
@end

static CVReturn cv_display_link_cb(CVDisplayLinkRef displayLink, const CVTimeStamp* now, const CVTimeStamp* outputTime, CVOptionFlags flagsIn, CVOptionFlags* flagsOut, void* displayLinkContext)
{
    CVReturn result = [(UbuMacView*)displayLinkContext getFrameForTime:outputTime];
    return result;
}
@implementation UbuMacView
- (void)prepareOpenGL {
    [super prepareOpenGL];

    NSLog(@"prepareOpenGL");
    
    // Synchronize buffer swaps with vertical refresh rate
    GLint swapInt = 1;

    [[self openGLContext] setValues:&swapInt forParameter:NSOpenGLCPSwapInterval];

    // Create a display link capable of being used with all active displays

    CVDisplayLinkCreateWithActiveCGDisplays(&display_link);

    // Set the renderer output callback function

    CVDisplayLinkSetOutputCallback(display_link, &cv_display_link_cb, self);

    // Set the display link for the current renderer

    CGLContextObj cglContext = [[self openGLContext] CGLContextObj];

    CGLPixelFormatObj cglPixelFormat = [[self pixelFormat] CGLPixelFormatObj];

    CVDisplayLinkSetCurrentCGDisplayFromOpenGLContext(display_link, cglContext, cglPixelFormat);

    // Activate the display link

    CVDisplayLinkStart(display_link);
}

- (CVReturn) getFrameForTime:(const CVTimeStamp *)outputTime {
    [[self openGLContext] makeCurrentContext];

    if (state.frame_count == 0) {
        state.desc.init_fn(UBU_MAC_OK);
    }

    if (state.desc.frame_fn) {
        state.desc.frame_fn();
    }

    [[self openGLContext] flushBuffer];

    state.frame_count++;
    
    return kCVReturnSuccess;
}

- (void)dealloc {
    NSLog(@"dealloc");
    CVDisplayLinkRelease(display_link);
    [super dealloc];
}
@end

void ubuAppMacRun(UbuMacAppDesc desc) {
    [NSApplication sharedApplication];
    state.app_dlg = [[UbuMacApplicationDelegate alloc] init];
    state.desc = desc;
    [NSApp setDelegate:state.app_dlg];
    [NSApp run];
}

void ubuAppMacShutdown() {
    [state.app_dlg release];
}

void ubuMacObjcRelease(void *ptr) {
    [(id)ptr release];
}


