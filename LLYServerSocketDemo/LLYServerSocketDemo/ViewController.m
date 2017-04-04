//
//  ViewController.m
//  LLYServerSocketDemo
//
//  Created by lly on 2017/4/4.
//  Copyright © 2017年 lly. All rights reserved.
//

#import "ViewController.h"
#import <sys/socket.h>
#import <netinet/in.h>
#import <arpa/inet.h>
#import <unistd.h>

CFWriteStreamRef outputStream;

@interface ViewController ()
{
    CFSocketRef _mSocket;
}

@property (weak) IBOutlet NSTextField *sendTextField;

@property (unsafe_unretained) IBOutlet NSTextView *contentTextView;


@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    // Do any additional setup after loading the view.
}


- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];

    // Update the view, if already loaded.
}


- (int)setupSocket{
    
    int bRet = 0;
    
    CFSocketContext sockContext = {0, // 结构体的版本，必须为0
        (__bridge void *)(self),
        NULL, // 一个定义在上面指针中的retain的回调， 可以为NULL
        NULL,
        NULL};
    
    _mSocket = CFSocketCreate(kCFAllocatorDefault, PF_INET, SOCK_STREAM, IPPROTO_TCP, kCFSocketAcceptCallBack, serverAcceptCallBack, &sockContext);
    if (NULL == _mSocket) {
        NSLog(@"Cannot create socket!");
        return 0;
    }
    
    int optval = 1;
    setsockopt(CFSocketGetNative(_mSocket), SOL_SOCKET, SO_REUSEADDR, // 允许重用本地地址和端口
               (void *)&optval, sizeof(optval));
    struct sockaddr_in addr4;
    memset(&addr4, 0, sizeof(addr4));
    addr4.sin_len = sizeof(addr4);
    addr4.sin_family = AF_INET;
    addr4.sin_port = htons(6666);
    addr4.sin_addr.s_addr = htonl(INADDR_ANY);
    CFDataRef address = CFDataCreate(kCFAllocatorDefault, (UInt8 *)&addr4, sizeof(addr4));
    
    if (kCFSocketSuccess != CFSocketSetAddress(_mSocket, address))
    {
        NSLog(@"Bind to address failed!");
        if (_mSocket)
            CFRelease(_mSocket);
        _mSocket = NULL;
        bRet = 0;
        return bRet;
    }
    
    CFRunLoopRef cfRunLoop = CFRunLoopGetCurrent();
    CFRunLoopSourceRef source = CFSocketCreateRunLoopSource(kCFAllocatorDefault, _mSocket, 0);
    CFRunLoopAddSource(cfRunLoop, source, kCFRunLoopCommonModes);
    CFRelease(source);

    bRet = 1;
    
    return bRet;
}

static void serverAcceptCallBack(CFSocketRef socket, CFSocketCallBackType type, CFDataRef address, const void *data, void *info){
    
    if (type == kCFSocketAcceptCallBack) {
     
        // 本地套接字句柄
        CFSocketNativeHandle nativeSocketHandle = *(CFSocketNativeHandle *)data;
        uint8_t name[SOCK_MAXADDRLEN];
        socklen_t nameLen = sizeof(name);
        if (0 != getpeername(nativeSocketHandle, (struct sockaddr *)name, &nameLen)) {
            NSLog(@"error");
            exit(1);
        }
        CFReadStreamRef iStream;
        CFWriteStreamRef oStream;
        // 创建一个可读写的socket连接
        CFStreamCreatePairWithSocket(kCFAllocatorDefault, nativeSocketHandle, &iStream, &oStream);
        if (iStream && oStream)
        {
            CFStreamClientContext streamContext = {0, info, NULL, NULL};
            if (!CFReadStreamSetClient(iStream, kCFStreamEventHasBytesAvailable,readStream, &streamContext))
            {
                exit(1);
            }
            
            if (!CFWriteStreamSetClient(oStream, kCFStreamEventCanAcceptBytes, writeStream, &streamContext))
            {
                exit(1);
            }
            CFReadStreamScheduleWithRunLoop(iStream, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
            CFWriteStreamScheduleWithRunLoop(oStream, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
            CFReadStreamOpen(iStream);
            CFWriteStreamOpen(oStream);
        } else
        {
            close(nativeSocketHandle);
        }

    }
}


// 读取数据
void readStream(CFReadStreamRef stream, CFStreamEventType eventType, void *clientCallBackInfo)
{
    UInt8 buff[255];
    CFReadStreamRead(stream, buff, 255);
    ///根据delegate显示到主界面去
    NSString *strMsg = [[NSString alloc]initWithFormat:@"客户端传来消息：%s",buff];
    ViewController *mSelf = (__bridge ViewController*)clientCallBackInfo;
    dispatch_async(dispatch_get_main_queue(), ^{
        [mSelf ShowMsg:strMsg];
    });
    
}
void writeStream (CFWriteStreamRef stream, CFStreamEventType eventType, void *clientCallBackInfo)
{
    outputStream = stream;
}


-(void)ShowMsg:(id)sender
{
    NSString *str = sender;
    str = [str stringByAppendingString:@"\n"];
    [self.contentTextView insertText:str];
}

- (void)serverStart{
    
    int res = [self setupSocket];
    if (res == 0) {
        exit(1);
    }
    CFRunLoopRun();
}

- (IBAction)startServer:(id)sender {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self serverStart];
    });
    [self ShowMsg:@"服务器启动成功！！！"];
}
- (IBAction)closeServer:(id)sender {
    if(CFSocketIsValid(_mSocket))
    {
        close(CFSocketGetNative(_mSocket));//关闭socket
        CFSocketInvalidate(_mSocket);
        CFRelease(_mSocket);
    }
}
- (IBAction)sendMessage:(id)sender {
    
    const char *str = [self.sendTextField.stringValue UTF8String];
    uint8_t *sendS = (uint8_t *)str;
    if (outputStream != NULL) {
        CFWriteStreamWrite(outputStream, sendS, strlen(str) + 1);
    }
    else{
        NSLog(@"send failed");
    }
}

@end
