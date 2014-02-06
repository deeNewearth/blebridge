//
//  BleBrViewController.m
//  bleBridge
//
//  Created by Deepayan Acharjya on 1/13/14.
//  Copyright (c) 2014 labizbille. All rights reserved.
//

#import "BleBrViewController.h"

@interface BleBrViewController (){
    NSDictionary *inputDict;
    NSString *inputHost;
    NSTimer *choiseTimerRef;
    float _timeOutSec;
    NSMutableData* receivedBuffer;
    
}
@property (weak, nonatomic) IBOutlet UIButton *refCancelBtn;
@property (weak, nonatomic) IBOutlet UIButton *refConnectBtn;

@property (weak, nonatomic) IBOutlet UILabel *label1;

@property (strong, nonatomic) BLE *ble;
@end

@implementation BleBrViewController

@synthesize ble;

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    [self.refCancelBtn setEnabled:NO];
    [self.refConnectBtn setEnabled:NO];
    
    self.label1.numberOfLines=0;
    self.label1.text=@"This app is only usefull when invoked thru a url";
    NSLog(@"App loaded");
    
    choiseTimerRef=nil;
    
    ble = [[BLE alloc] init];
    [ble controlSetup];
    ble.delegate = self;
    
    _timeOutSec=30;
    

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleURLOpen:)
                                                 name:@"urlOpenNotification" object:nil];
    
}

-(void)viewWillDisappear : (BOOL)animated{
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                            name:@"urlOpenNotification" object:nil];

    
    NSLog(@"App un loaded");
 
    [super viewWillDisappear :(BOOL)animated];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(NSData *)hexStringToData:(NSString *)hexString
{
    int j=0;
    Byte bytes[[hexString length]];
    for(int i=0;i<[hexString length];i++)
    {
        int int_ch =0;
        
        unichar hex_char1 = [hexString characterAtIndex:i];
        int int_ch1 =0;
        if(hex_char1 >= '0' && hex_char1 <='9')
            int_ch1 = (hex_char1-48)*16;
        else if(hex_char1 >= 'A' && hex_char1 <='F')
            int_ch1 = (hex_char1-55)*16;
        else if(hex_char1 >= 'a' && hex_char1 <='f')
            int_ch1 = (hex_char1-87)*16;
        i++;
        int int_ch2 =0;
        
        if(i<[hexString length])
        {
        unichar hex_char2 = [hexString characterAtIndex:i];
        
        if(hex_char2 >= '0' && hex_char2 <='9')
            int_ch2 = (hex_char2-48);
        else if(hex_char1 >= 'A' && hex_char1 <='F')
            int_ch2 = hex_char2-55;
        else if(hex_char1 >= 'a' && hex_char1 <='f')
            int_ch2 = hex_char2-87;
        }
        
        int_ch = int_ch1+int_ch2;
        
        bytes[j] = int_ch;
        j++;
    }
    NSData *newData = [[NSData alloc] initWithBytes:bytes length:[hexString length]/2];
    return newData;
}

-(NSString*)hexRepresentation:(NSData*)inputData
{
    const unsigned char* bytes = (const unsigned char*)[inputData bytes];
    NSUInteger nbBytes = [inputData length];
    
    /*
    //If spaces is true, insert a space every this many input bytes (twice this many output characters).
    static const NSUInteger spaceEveryThisManyBytes = 4UL;
    //If spaces is true, insert a line-break instead of a space every this many spaces.
    static const NSUInteger lineBreakEveryThisManySpaces = 4UL;
    const NSUInteger lineBreakEveryThisManyBytes = spaceEveryThisManyBytes * lineBreakEveryThisManySpaces;
    */
     
    NSUInteger strLen = 2*nbBytes;
    
    NSMutableString* hex = [[NSMutableString alloc] initWithCapacity:strLen];
    for(NSUInteger i=0; i<nbBytes; ) {
        [hex appendFormat:@"%02X", bytes[i]];
        //We need to increment here so that the every-n-bytes computations are right.
        ++i;
        
        /*if (spaces) {
            if (i % lineBreakEveryThisManyBytes == 0) [hex appendString:@"\n"];
            else if (i % spaceEveryThisManyBytes == 0) [hex appendString:@" "];
        }*/
    }
    
    return hex;
}

#pragma mark - BLE delegate
const uint8_t MAGIC_BYTES[] = { 0x45, 0xFF, 0x7E, 0xF0};

-(void) bleDidConnect
{
    NSLog(@"->Connected");
    
    if(ble.activePeripheral)
    {
        self.label1.text=[NSString stringWithFormat:@"Connected to\n %@", ble.activePeripheral.name];
        
        if(!inputDict  || ![[inputDict allKeys] containsObject:@"Data"])
        {
            NSLog(@"we should not be here if dict is null or no data");
            return ;
        }
        
        NSData* toSend =[self hexStringToData:[inputDict objectForKey:@"Data"] ];
        
        unsigned int len = [toSend length];
        NSLog(@"datasize %d bytes",len);
        if(len>1024)
        {
            [self returnToCaller:@"Data too large. Max 1024 bytes please."];
            return;
        }
        
        //initialize the received buffer
        receivedBuffer =nil;
        
        //write magicbytes
        NSMutableData* sendPacket = [NSMutableData dataWithBytes:MAGIC_BYTES length:sizeof(MAGIC_BYTES)];
        
        
        //write length little endian
        uint16_t little = (uint16_t)NSSwapHostIntToLittle(len);
        [sendPacket appendBytes:&little length:2];
        
        [sendPacket appendData:toSend];
        
        //write actual data
        NSLog(@"sending %d bytes",[sendPacket length]);
        [ble write:sendPacket];
        
        
        
        
    }
    else
    {
        NSLog(@"no active peripheral at ble connect");
        self.label1.text=@"Connection failed";
    }
}

// When data is comming, this will be called
-(void) bleDidReceiveData:(unsigned char *)inData length:(int)inLen
{
    NSLog(@"Data received : %d bytes", inLen);
    
    if(!receivedBuffer)
    {
        NSLog(@"first received result");
        receivedBuffer =[NSMutableData new];
    }
    else
    {
        NSLog(@"additional data comin in");
    }
    
    [receivedBuffer appendBytes:inData length:inLen];
    
    NSLog(@"Input buffer : %@",[receivedBuffer description]);

    const uint8_t* buffBytes= [receivedBuffer bytes];
    size_t buffLen =[receivedBuffer length];

    
    //verify magic bytes
    if(buffLen<sizeof(MAGIC_BYTES)+sizeof(uint16_t))
    {
        
        NSLog(@"received data too small for magic bytes");
        return;
    }
    
    
    for(size_t i=0;i<sizeof(MAGIC_BYTES);i++)
    {
        if(buffBytes[i]!=MAGIC_BYTES[i])
        {
            //we actually just ignore as we might be getting junk for a previous aborted call
            NSLog(@"received data NOT magic bytes %0X - %0X ",buffBytes[i],MAGIC_BYTES[i]);
            receivedBuffer =nil;
            return;
        }
    }
    
    
    //get the length
    uint16_t little =0;
    memcpy(&little,buffBytes+sizeof(MAGIC_BYTES),sizeof(uint16_t));
    int dataLen = NSSwapLittleIntToHost(little);
    
    if(buffLen<sizeof(MAGIC_BYTES)+sizeof(uint16_t)+dataLen)
    {
        //we actually just ignore as we might be getting junk for a previous aborted call
        NSLog(@"received data too small for complete length");
        return;
    }
    
    NSData* dataReceived = [NSData dataWithBytes:buffBytes+sizeof(MAGIC_BYTES)+sizeof(uint16_t) length:dataLen];
    receivedBuffer=nil;
    [self returnToCaller:nil andData:dataReceived ];
    
}

- (void)bleDidDisconnect
{
    NSLog(@"->Disconnected");
}

#pragma mark URL Notification

-(void)returnToCaller:(NSString *)msg{
    [self returnToCaller:msg andData:nil];
}

-(void)returnToCaller:(NSString *)msg andData:(NSData*)data{
    
    if(choiseTimerRef)
    {
        [choiseTimerRef invalidate];
        choiseTimerRef=nil;
    }
    
    if(!msg)
    {
        NSLog(@"Return to called with NULL msg");
    }
    else
    {
        NSLog(@"Return to called with msg : %@", msg);
    
        self.label1.text=msg;
    }
    
    
    [self.refCancelBtn setEnabled:NO];
    [self.refConnectBtn setEnabled:NO];
    
    if (ble.activePeripheral)
    {
        if(ble.activePeripheral.state == CBPeripheralStateConnected)
        {
            [[ble CM] cancelPeripheralConnection:[ble activePeripheral]];
        }
    }


    if(!inputDict  || ![[inputDict allKeys] containsObject:@"retUrl"])
    {
        NSLog(@"we should not be here if dict is null or no retUrl");
        return ;
    }
    
    if(!data)
        data = [NSData new];
    
    NSString* retPart;
    NSString* retMsg;
    
    if(!msg)
    {
        retPart = @"data";
        retMsg =[self hexRepresentation:data];
    }
    else
    {
        retPart = @"Result";
        retMsg=msg;
        
    }
    
    CFStringRef safeString = CFURLCreateStringByAddingPercentEscapes (
                                                                      NULL,
                                                                      (CFStringRef)retMsg,
                                                                      NULL,
                                                                      CFSTR("/%&=?$#+-~@<>|\\*,.()[]{}^!"),
                                                                      kCFStringEncodingUTF8
                                                                      );
    
    NSString* returnState = @"";
    
    if([[inputDict allKeys] containsObject:@"State"])
    {
        returnState=[inputDict objectForKey:@"State"];
        if(NULL == returnState)
            returnState = @"";
    }

    
    NSString* retURL = [NSString stringWithFormat:@"%@?%@=%@&State=%@",
                        [inputDict objectForKey:@"retUrl"],
                        retPart, CFBridgingRelease(safeString),
                        returnState
                        ];
    
    NSLog(@"Return URL is : %@",retURL);
    
    
    NSURL *url = [NSURL URLWithString:retURL];
    [[UIApplication sharedApplication] openURL:url];
    
    self.label1.text=@"This app is only usefull when invoked thru a url";
}

- (NSDictionary *)parseQueryString:(NSString *)query {
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] initWithCapacity:6];
    NSArray *pairs = [query componentsSeparatedByString:@"&"];
    
    for (NSString *pair in pairs) {
        NSArray *elements = [pair componentsSeparatedByString:@"="];
        NSString *key = [[elements objectAtIndex:0] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        NSString *val = [[elements objectAtIndex:1] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        
        [dict setObject:val forKey:key];
    }
    return dict;
}

-(NSString*)checkURLStatus:(NSNotification*)_notification
{
    //[[self navigationController] popToRootViewControllerAnimated:YES];
    NSURL *url=[[_notification userInfo] objectForKey:@"url"];
    NSLog(@"url recieved: %@", url);
    NSLog(@"query string: %@", [url query]);
    NSLog(@"host: %@", [url host]);
    NSLog(@"url path: %@", [url path]);
    NSDictionary *dict = [self parseQueryString:[url query]];
    NSLog(@"query dict: %@", dict);
    
    
    /* returning directly from here is an issue causes screen blank outs.
     So use a Timer to return from here
     */
    
    if (ble.activePeripheral)
    {
        if(ble.activePeripheral.state == CBPeripheralStateConnected)
        {
            [[ble CM] cancelPeripheralConnection:[ble activePeripheral]];

            return @"a BLE device is already connected. Try again in a bit";
        }
    }
    
    if(choiseTimerRef)
    {
        return @"Still waiting for a previous operation to complete";
    }
    
    if(inputDict)
        inputDict =nil;
    if(inputHost)
        inputHost=nil;
    
    if(![[dict allKeys] containsObject:@"Name"])
    {
        return @"Invalid input: No name in URL";
    }
    
    if(![[dict allKeys] containsObject:@"Data"])
    {
        return @"Invalid input: No data in URL";
    }
    
    if(![[dict allKeys] containsObject:@"retUrl"])
    {

        return @"Invalid input: No return location in URL";
    }
    
    _timeOutSec=30;
    if([[dict allKeys] containsObject:@"timeOut"])
    {
        NSNumberFormatter * f = [[NSNumberFormatter alloc] init];
        [f setNumberStyle:NSNumberFormatterDecimalStyle];
        NSNumber * myNumber = [f numberFromString:[dict objectForKey:@"timeOut"]];
        if(myNumber)
            _timeOutSec =[myNumber floatValue];
            
        
    }
    
    
    inputDict=dict;
    inputHost=[url host];
    
     NSLog(@"Dev name: %@", [dict objectForKey:@"Name"]);
    
    self.label1.text=[NSString stringWithFormat:@"Looking for %@", [inputDict objectForKey:@"Name"]];
    
    return nil;
    
}

-(void)handleURLOpen:(NSNotification*)_notification
{
    
    NSString* error = [self checkURLStatus:_notification];
   
    if(error)
    {
        NSLog(@"Triggering invalid choice Timer");
        [NSTimer scheduledTimerWithTimeInterval:(float)5.0 target:self selector:@selector(invalidOpenTimer:)
                                       userInfo:[NSDictionary dictionaryWithObject:error
                                                                            forKey:@"msg"] repeats:NO];
        return;
    }
   
    NSLog(@"Staring BLE lookup");
    
    if (ble.peripherals)
        ble.peripherals = nil;
    
    [ble findBLEPeripherals:2];
    

    //make sure timeoiut is greater then this time
    if(_timeOutSec<2.0)
        _timeOutSec=30;
    
    [NSTimer scheduledTimerWithTimeInterval:(float)2.0 target:self selector:@selector(connectionTimer:) userInfo:nil repeats:NO];
    
}

-(void) invalidOpenTimer:(NSTimer *)timer
{
    NSLog(@"invalidOpenTimer time bite");
    NSDictionary *dict = [timer userInfo];
    
    
    [self returnToCaller:[dict objectForKey:@"msg"]];
}

#pragma mark - Actions
- (IBAction)ConnectBtn:(id)sender {
    
    NSLog(@"connect touched");

    [self.refCancelBtn setEnabled:NO];
    [self.refConnectBtn setEnabled:NO];

    
    CBPeripheral* p =[self findPeripheral];
    if(p)
    {
        [ble connectPeripheral:p];
     
    }
    else
    {
        [self returnToCaller:@"Device not found"];
        return;
    }
    
}


- (IBAction)CancelBtn:(id)sender {
    NSLog(@"Cancel touched");
    
    [self.refCancelBtn setEnabled:NO];
    [self.refConnectBtn setEnabled:NO];

    [self returnToCaller:@"User cancelled"];
}

-(CBPeripheral*) findPeripheral{
    
    if(!inputDict  || !inputHost)
    {
        NSLog(@"we should not be here if dict or host is null");
        return nil;
    }
    
    for (int i = 0; i < ble.peripherals.count; i++)
    {
        CBPeripheral *p = [ble.peripherals objectAtIndex:i];
        
        if (p.identifier != NULL)
        {
            if ([inputHost isEqualToString: p.identifier.UUIDString])
            {
                
                NSLog(@"Found host device %@", p.identifier.UUIDString);
                return p;
            }
        }
        else
            NSLog(@"%d  |  NULL", i);
        
    }

    return nil;
}

-(void) choiseTimer:(NSTimer *)timer
{
    NSLog(@"Choise time byte");
    [self returnToCaller:@"Timeout"];
}

-(void) connectionTimer:(NSTimer *)timer
{
    CBPeripheral* p =[self findPeripheral];
    
    if(p)
    {
        self.label1.text=[NSString stringWithFormat:@"Allow connection to\n %@", p.name];
        [self.refCancelBtn setEnabled:YES];
        [self.refConnectBtn setEnabled:YES];
        
        choiseTimerRef =[NSTimer scheduledTimerWithTimeInterval:_timeOutSec target:self selector:@selector(choiseTimer:) userInfo:nil repeats:NO];

    }
    else
        [self returnToCaller:@"Device not found"];
    
}

@end
