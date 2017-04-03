//
//  ViewController.m
//  LLYClientSocketDemo
//
//  Created by lly on 2017/4/3.
//  Copyright © 2017年 lly. All rights reserved.
//

#import "ViewController.h"
#import <sys/socket.h>
#import <netinet/in.h>
#import <arpa/inet.h>
#import <unistd.h>

@interface ViewController ()
{
    CFSocketRef _mSocket;
}

@property (weak, nonatomic) IBOutlet UITextField *serverIPTextField;
@property (weak, nonatomic) IBOutlet UITextField *sendContentTextField;
@property (weak, nonatomic) IBOutlet UITextView *mTextView;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


- (void)connectServerWithServerIP:(NSString *)serverIP{

    CFSocketContext socketContext = {
        0,//结构体的版本，必须为0
        (__bridge void *)(self),
        NULL,
        NULL,
        NULL,
    };
    
    _mSocket = CFSocketCreate(kCFAllocatorDefault,//为新对象分配内存，可以为nil
                              PF_INET,//协议族，如果为0或者负数，则默认为PF_INET
                              SOCK_STREAM,//套接字类型，如果协议族为PF_INET,则它会默认为SOCK_STREAM
                              IPPROTO_TCP,//套接字协议，如果协议族是PF_INET且协议是0或者负数，它会默认为IPPROTO_TCP
                              kCFSocketConnectCallBack,//触发回调函数的socket消息类型，具体见Callback Types
                              socketMessageCallBack,//上面情况下触发的回调函数
                              &socketContext);//一个持有CFSocket结构信息的对象，可以为nil
    if (_mSocket != NULL) {
        struct sockaddr_in addr4;//IPV4
        memset(&addr4, 0, sizeof(addr4));
        addr4.sin_len = sizeof(addr4);
        addr4.sin_family = AF_INET;
        addr4.sin_port = htons(8888);
        addr4.sin_addr.s_addr = inet_addr([serverIP UTF8String]);//把字符串的地址转换为机器可识别的网络地址

        //把sockaddr_in结构体中的地址转换为Data
        CFDataRef address = CFDataCreate(kCFAllocatorDefault,
                                         (UInt8 *)&addr4, sizeof(addr4));
        CFSocketConnectToAddress(_mSocket,//当前连接的socket
                                 address,//CFDataRef类型的包含上面socket的远程地址的对象
                                 -1);//连接超时时间，如果为负，则不尝试连接，而是把连接放在后台进行，如果_socket消息类型为kCFSocketConnectCallBack，将会在连接成功或失败的时候在后台触发回调函数
        
        CFRunLoopRef cRunRef = CFRunLoopGetCurrent();//获取当前线程的循环
        //创建一个循环，但并没有真正加如到循环中，需要调用CFRunLoopAddSource
        CFRunLoopSourceRef sourceRef = CFSocketCreateRunLoopSource(kCFAllocatorDefault, _mSocket, 0);
        CFRunLoopAddSource(cRunRef, sourceRef, kCFRunLoopCommonModes);
        CFRelease(cRunRef);
        CFRelease(sourceRef);
        
        NSLog(@"start connect");
    }
}

static void socketMessageCallBack(CFSocketRef socket, CFSocketCallBackType type, CFDataRef address, const void *data, void *info){
    
    ViewController *mSelf = (__bridge ViewController *)info;
    
    switch (type) {
        case kCFSocketNoCallBack:
        {
            NSLog(@"no callback");
        }
            break;
        case kCFSocketReadCallBack:
        {
            NSLog(@"read callback");
        }
            break;
            
        case kCFSocketAcceptCallBack:
        {
            NSLog(@"accept callback");
        }
            break;
            
        case kCFSocketDataCallBack:
        {
            NSLog(@"data callback");
            
        }
            break;
            
        case kCFSocketConnectCallBack:
        {
            NSLog(@"connect callback");
            //data为回调的错误码,为NULL则为成功
            if (data != NULL)
            {
                NSLog(@"连接失败");
                return;
            }
            else{
                //更新界面需要在主线程
                dispatch_async(dispatch_get_main_queue(), ^{
                    [mSelf ShowMsg:@"服务器连接成功,现在可以开始通信了!!!"];
                });
                //持续的接收数据，不能在主线程做，会阻塞当前线程，放到一个子线程去做。
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    [mSelf readMessageLoop];
                });
            }

        }
            break;
            
        case kCFSocketWriteCallBack:
        {
            NSLog(@"write callback");
        }
            break;
            
        default:
            break;
    }
    
}

- (void)readMessageLoop{

    while (1) {
        char buffer[1024];
        ssize_t recvLen = recv(CFSocketGetNative(_mSocket), buffer, sizeof(buffer), 0);
        if (recvLen > 0) {
            @autoreleasepool {
                NSString *str = @"服务器发来数据：";
                NSData *data = [NSData dataWithBytes:buffer length:recvLen];
                str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                //回界面显示信息
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self ShowMsg:str];
                });
            }
        }
    }
    
}


-(void)ShowMsg:(id)sender
{
    NSString *str = sender;
    str = [str stringByAppendingString:@"\n"];
    [self.mTextView insertText:str];
}

// 发送数据
- (void)sendMessage {
    const char *sData = [self.sendContentTextField.text UTF8String];
    send(CFSocketGetNative(_mSocket), sData, strlen(sData) + 1, 0);
}

- (IBAction)connectServerBtnClicked:(id)sender {
    
    [self connectServerWithServerIP:self.serverIPTextField.text];
    
}
- (IBAction)closeServerConnectBtnClicked:(id)sender {
    if (_mSocket) {
        CFSocketInvalidate(_mSocket);
        CFRelease(_mSocket);
    }
}
- (IBAction)sendBtnClicked:(id)sender {
    [self sendMessage];
}

@end
