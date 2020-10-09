//
//  AppController.m
//  Late5
//
//  Created by kyab on 2020/09/09.
//  Copyright © 2020 kyab. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Foundation/Foundation.h>
#import "AppController.h"
#import "AudioToolbox/AudioToolbox.h"
#include "spleeter/spleeter.h"
#include <vector>
#include "public.sdk/source/main/pluginfactory.h"
#include "pluginterfaces/base/ipluginbase.h"
#include "pluginterfaces/vst/ivstaudioprocessor.h"
#include "pluginterfaces/vst/ivsteditcontroller.h"
#include "pluginterfaces/gui/iplugview.h"
#include "public.sdk/source/common/memorystream.h"
// memorystream.cpp が libsdk.a に含まれていないので、この memorystream.cpp をインクルードして直接コンパイルする。
// この方法はちょっと横着なので、ここで memorystream.cpp を直接インクルードするよりも、
// memorystream.cpp を IDE のプロジェクトに追加してちゃんとコンパイルするようにしたほうが良い。
#include "public.sdk/source/common/memorystream.cpp"
#include "CEditorHost.h"


using namespace Steinberg;
Vst::MyComponentHandler componentHandler = Vst::MyComponentHandler();
Vst::HostApplication hostApplication = Vst::HostApplication();


//#define SPLEETER_MODELS "/Users/koji/work/PartScratch/spleeterpp/build/models/offline"
#define LATE_SAMPLE 132288  // ~= 44100*3, can be devide by 32.
//#define LATE_SAMPLE 44096
//#define LATE_SAMPLE 88192

Vst::IAudioProcessor *g_audioProcessor= NULL;


static double linearInterporation(int x0, double y0, int x1, double y1, double x){
    if (x0 == x1){
        return y0;
    }
    double rate = (x - x0) / (x1 - x0);
    double y = (1.0 - rate)*y0 + rate*y1;
    return y;
}



@implementation AppController

-(void)awakeFromNib{
    NSLog(@"Late5 Studio awakeFromNib");
    
    [self initSpleeter];
    
    _dq = dispatch_queue_create("spleeter", DISPATCH_QUEUE_SERIAL);
    //    https://stackoverflow.com/questions/17690740/create-a-high-priority-serial-dispatch-queue-with-gcd/17690878
    dispatch_set_target_queue(_dq, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0));
    
    _ring = [[RingBuffer alloc] init];      //the ring for the view
    _ring5a = [[RingBuffer alloc] init];
    _ring5b = [[RingBuffer alloc] init];
    
    _ringVocals = [[RingBuffer alloc] init];
    _ringDrums = [[RingBuffer alloc] init];
    _ringBass = [[RingBuffer alloc] init];
    _ringPiano = [[RingBuffer alloc] init];
    _ringOther = [[RingBuffer alloc] init];
    
    _volVocals = 1.0;
    _volDrums = 1.0;
    _volBass = 1.0;
    _volPiano = 1.0;
    _volOther = 1.0;
    
    _panVocals = 0.0;
    _panDrums = 0.0;
    _panBass = 0.0;
    _panPiano = 0.0;
    _panOther = 0.0;
    
    _scratchVocals = NO;
    _scratchDrums = NO;
    _scratchBass = NO;
    _scratchPiano = NO;
    _scratchOther = NO;
    
    _tempRing = _ring5a;
    
    _ae = [[AudioEngine alloc] init];
    if([_ae initialize]){
        NSLog(@"AudioEngine all OK");
    }else{
        NSLog(@"AudioEngine NG");
    }
    [_ae setRenderDelegate:(id<AudioEngineDelegate>)self];
    
    [_ae changeSystemOutputDeviceToBGM];
    [_ae startInput];
    [_ae startOutput];
    

}

-(void)initSpleeter{
    std::error_code err;
    NSLog(@"Initializing spleeter");
    
    NSString *resourcePath = [[NSBundle mainBundle] resourcePath];
    
    spleeter::Initialize(
                         std::string(resourcePath.UTF8String),{spleeter::FiveStems}, err);
    NSLog(@"spleeter Initialize err = %d", err.value());
    
    //split empty for warm up.
    {
        NSLog(@"First Split");
        std::vector<float> fragment(44100*2);
        spleeter::Waveform vocals, drums, bass, piano, other;
        auto source = Eigen::Map<spleeter::Waveform>(fragment.data(),
                                                    2, fragment.size()/2);
        spleeter::Split(source, &vocals, &drums, &bass, &piano, &other,err);
        NSLog(@"First split error = %d", err.value());
    }
    
}




- (IBAction)volVocalsChanged:(id)sender {
    NSSlider *slider = (NSSlider *)sender;
    _volVocals = [slider doubleValue];
}
- (IBAction)volDrumsChanged:(id)sender {
    NSSlider *slider = (NSSlider *)sender;
    _volDrums = [slider doubleValue];
}
- (IBAction)volBassChanged:(id)sender {
    NSSlider *slider = (NSSlider *)sender;
    _volBass = [slider doubleValue];
}
- (IBAction)volPianoChanged:(id)sender {
    NSSlider *slider = (NSSlider *)sender;
    _volPiano = [slider doubleValue];
}
- (IBAction)volOtherChanged:(id)sender {
    NSSlider *slider = (NSSlider *)sender;
    _volOther = [slider doubleValue];
}


- (IBAction)panVocalsChanged:(id)sender {
    CircularSlider *slider = (CircularSlider *)sender;
    _panVocals = [slider floatValue];
}
- (IBAction)panDrumsChanged:(id)sender {
    CircularSlider *slider = (CircularSlider *)sender;
    _panDrums = [slider floatValue];
}
- (IBAction)panBassChanged:(id)sender {
    CircularSlider *slider = (CircularSlider *)sender;
    _panBass = [slider floatValue];
}
- (IBAction)panPianoChanged:(id)sender {
    CircularSlider *slider = (CircularSlider *)sender;
    _panPiano = [slider floatValue];
}
- (IBAction)panOtherChanged:(id)sender {
    CircularSlider *slider = (CircularSlider *)sender;
    _panOther = [slider floatValue];
}


- (IBAction)scratchVocalsChanged:(id)sender {
    NSButton *chk = (NSButton *)sender;
    _scratchVocals = ([chk state] == NSOnState);
}
- (IBAction)scratchDrumsChanged:(id)sender {
    NSButton *chk = (NSButton *)sender;
    _scratchDrums = ([chk state] == NSOnState);
}
- (IBAction)scratchBassChanged:(id)sender {
    NSButton *chk = (NSButton *)sender;
    _scratchBass = ([chk state] == NSOnState);
}
- (IBAction)scratchPianoChanged:(id)sender {
    NSButton *chk = (NSButton *)sender;
    _scratchPiano = ([chk state] == NSOnState);
}
- (IBAction)scratchOtherChanged:(id)sender {
    NSButton *chk = (NSButton *)sender;
    _scratchOther = ([chk state] == NSOnState);
}





- (OSStatus) outCallback:(AudioUnitRenderActionFlags *)ioActionFlags inTimeStamp:(const AudioTimeStamp *) inTimeStamp inBusNumber:(UInt32) inBusNumber inNumberFrames:(UInt32)inNumberFrames ioData:(AudioBufferList *)ioData{
    
    if (![_ae isPlaying]){
        UInt32 sampleNum = inNumberFrames;
        float *pLeft = (float *)ioData->mBuffers[0].mData;
        float *pRight = (float *)ioData->mBuffers[1].mData;
        bzero(pLeft, sizeof(float)*sampleNum);
        bzero(pRight, sizeof(float)*sampleNum);
        return noErr;
    }
    
    if([_ringOther isShortage]){
        UInt32 sampleNum = inNumberFrames;
        float *pLeft = (float *)ioData->mBuffers[0].mData;
        float *pRight = (float *)ioData->mBuffers[1].mData;
        bzero(pLeft, sizeof(float)*sampleNum);
        bzero(pRight, sizeof(float)*sampleNum);
        return noErr;
    }

    RingBuffer *rings[5];
    rings[0] = _ringVocals;
    rings[1] = _ringDrums;
    rings[2] = _ringBass;
    rings[3] = _ringPiano;
    rings[4] = _ringOther;
    
    float volumes[5];
    volumes[0] = _volVocals;
    volumes[1] = _volDrums;
    volumes[2] = _volBass;
    volumes[3] = _volPiano;
    volumes[4] = _volOther;
    
    float pans[5];
    pans[0] = _panVocals;
    pans[1] = _panDrums;
    pans[2] = _panBass;
    pans[3] = _panPiano;
    pans[4] = _panOther;
    
    Boolean scratch[5];
    scratch[0] = _scratchVocals;
    scratch[1] = _scratchDrums;
    scratch[2] = _scratchBass;
    scratch[3] = _scratchPiano;
    scratch[4] = _scratchOther;
    std::vector<UInt32> scratches;
    std::vector<UInt32> noScratches;
    for(int i = 0; i < 5; i++){
        if (scratch[i]){
            scratches.push_back(i);
        }else{
            noScratches.push_back(i);
        }
    }
    
    [_ring advanceReadPtrSample:inNumberFrames];
        
    std::vector<float> leftSrc(inNumberFrames);
    std::vector<float> rightSrc(inNumberFrames);
    
    
    for(UInt32 si : noScratches){
        float *startLeft = [rings[si] readPtrLeft];
        float *startRight = [rings[si] readPtrRight];
        for(int i = 0 ; i < inNumberFrames; i++){
            
            //pan control
            float panVolLeft = 1.0;
            float panVolRight = 1.0;
            if (pans[si] >= 0){     //say 0.8
                panVolRight = 1.0;
                panVolLeft = 1.0 - pans[si];
            }else{
                panVolLeft = 1.0;
                panVolRight = 1.0 + pans[si];
            }
            leftSrc[i] += *(startLeft + i) * volumes[si] * panVolLeft;
            rightSrc[i] += *(startRight + i) * volumes[si] * panVolRight;
            
        }
        [rings[si] advanceReadPtrSample:inNumberFrames];
        [rings[si] advanceNaturalPtrSample:inNumberFrames];

    }
    
    if(g_audioProcessor){
        Vst::ProcessData processData = Vst::ProcessData();
        processData.processMode = Vst::kRealtime;
        processData.symbolicSampleSize = Vst::kSample32;
        processData.numSamples = inNumberFrames;
        processData.numInputs = 1;
        processData.numOutputs = 1;
        
        Vst::AudioBusBuffers inputs =  Vst::AudioBusBuffers();
        inputs.numChannels = 2;
        inputs.silenceFlags = 0;
        inputs.channelBuffers32 = (Vst::Sample32 **)malloc(2 * sizeof(Vst::Sample32 *));
        inputs.channelBuffers32[0] = leftSrc.data();
        inputs.channelBuffers32[1] = rightSrc.data();
        
        
        std::vector<float> leftDst(inNumberFrames);
        std::vector<float> rightDst(inNumberFrames);
        
        Vst::AudioBusBuffers outputs = Vst::AudioBusBuffers();
        outputs.numChannels = 2;
        outputs.silenceFlags = 0;
        outputs.channelBuffers32 = (Vst::Sample32 **)malloc(2 * sizeof(Vst::Sample32 *));
        outputs.channelBuffers32[0] = leftDst.data();
        outputs.channelBuffers32[1] = rightDst.data();
        
        processData.inputs = &inputs;
        processData.outputs = &outputs;
        
        tresult res = g_audioProcessor->process(processData);
        if (res != kResultOk){
            NSLog(@"IAudopProcessor::process() failed with : %d", res);
        }
        
        memcpy(ioData->mBuffers[0].mData, leftDst.data(), inNumberFrames * sizeof(float));
        memcpy(ioData->mBuffers[1].mData, rightDst.data(), inNumberFrames * sizeof(float));
        
    }else{

        memcpy(ioData->mBuffers[0].mData, leftSrc.data(), inNumberFrames * sizeof(float));
        memcpy(ioData->mBuffers[1].mData, rightSrc.data(), inNumberFrames * sizeof(float));
    }
    
    return noErr;
    
    
}

- (OSStatus) inCallback:(AudioUnitRenderActionFlags *)ioActionFlags inTimeStamp:(const AudioTimeStamp *) inTimeStamp inBusNumber:(UInt32) inBusNumber inNumberFrames:(UInt32)inNumberFrames ioData:(AudioBufferList *)ioData{
    
    AudioBufferList *bufferList = (AudioBufferList *)malloc(sizeof(AudioBufferList) +  sizeof(AudioBuffer)); // for 2 buffers for left and right
    

    float *leftPtr = [_tempRing writePtrLeft];
    float *rightPtr = [_tempRing writePtrRight];

    
    bufferList->mNumberBuffers = 2;
    bufferList->mBuffers[0].mDataByteSize = 32*inNumberFrames;
    bufferList->mBuffers[0].mNumberChannels = 1;
    bufferList->mBuffers[0].mData = leftPtr;
    bufferList->mBuffers[1].mDataByteSize = 32*inNumberFrames;
    bufferList->mBuffers[1].mNumberChannels = 1;
    bufferList->mBuffers[1].mData = rightPtr;
    
    
    OSStatus ret = [_ae readFromInput:ioActionFlags inTimeStamp:inTimeStamp inBusNumber:inBusNumber inNumberFrames:inNumberFrames ioData:bufferList];
    
    if ( 0!=ret ){
        NSError *err = [NSError errorWithDomain:NSOSStatusErrorDomain code:ret userInfo:nil];
        NSLog(@"Failed AudioUnitRender err=%d(%@)", ret, [err description]);
        return ret;
    }
    
    free(bufferList);
    
    [_tempRing advanceWritePtrSample:inNumberFrames];
    [_ring advanceWritePtrSample:inNumberFrames];

    if ([_ae isRecording]){
        
        float *startPtrLeft = [_tempRing startPtrLeft];
        float *currentPtrLeft = [_tempRing writePtrLeft];
        if (currentPtrLeft - startPtrLeft >= LATE_SAMPLE){
            
            RingBuffer *bgRing = self->_tempRing;
            
            //switch tempRing
            if (self->_tempRing == self->_ring5a){
                self->_tempRing = self->_ring5b;
            }else{
                self->_tempRing = self->_ring5a;
            }
            
            dispatch_async(_dq, ^{

                //ready interleaved samples for spleeter
                std::vector<float> fragment(44100*2/*head*/ + LATE_SAMPLE*2);
                for(int i = 0; i < LATE_SAMPLE; i++){
                    fragment[44100*2 + i*2] = *([bgRing startPtrLeft]+i);
                    fragment[44100*2 +i*2+1] = *([bgRing startPtrRight]+i);
                }

                //spleet it!
                spleeter::Waveform vocals, drums, bass, piano, other;
                auto source = Eigen::Map<spleeter::Waveform>(fragment.data(),
                                                            2, fragment.size()/2);
                std::error_code err;
                spleeter::Split(source, &vocals, &drums, &bass, &piano, &other,err);
//                NSLog(@"Split error = %d", err.value());
                
                std::vector<float> left(LATE_SAMPLE);
                std::vector<float> right(LATE_SAMPLE);
                spleeter::Waveform *waveForms[5];
                waveForms[0] = &vocals;
                waveForms[1] = &drums;
                waveForms[2] = &bass;
                waveForms[3] = &piano;
                waveForms[4] = &other;
                
                RingBuffer *rings[5];
                rings[0] = self->_ringVocals;
                rings[1] = self->_ringDrums;
                rings[2] = self->_ringBass;
                rings[3] = self->_ringPiano;
                rings[4] = self->_ringOther;
                
                for (int si = 0; si < 5 ; si++){
                    //back to non-interleaved,
                    for (int i = 0; i < LATE_SAMPLE; i++){
                        left[i] = *(waveForms[si]->data() + 44100*2 + i*2);
                        right[i] = *(waveForms[si]->data() + 44100*2 + i*2+1);
                    }
                    
                    //then write to rings
                    memcpy([rings[si] writePtrLeft], left.data(), LATE_SAMPLE*sizeof(float));
                    memcpy([rings[si] writePtrRight], right.data(), LATE_SAMPLE*sizeof(float));
                    [rings[si] advanceWritePtrSample:LATE_SAMPLE];
                    
                }
                
                [bgRing resetBuffer];
            });
        }
    }
    
    return ret;
}

-(void)terminate{
    [_ae stopOutput];
    [_ae stopInput];
    [_ae restoreSystemOutputDevice];
    
}


typedef IPluginFactory* (*THEAPI)();
typedef bool (*BundleEntryFunc) (CFBundleRef);

//#define BUNDLE_PATH @"/Library/Audio/Plug-Ins/VST/OldSkoolVerb.vst3"
//#define BUNDLE_PATH @"/Library/Audio/Plug-Ins/VST/SPAN.vst3"
//#define BUNDLE_PATH @"/Library/Audio/Plug-Ins/VST3/UpStereo.vst3"
//#define BUNDLE_PATH @"/Users/koji/work/VST_SDK/VST3_SDK/build/VST3/Debug/helloworld.vst3"
//#define BUNDLE_PATH @"/Users/koji/work/VST_SDK/VST3_SDK/build/VST3/Debug/helloworldWithVSTGUI.vst3"
//#define BUNDLE_PATH @"/Users/koji/work/VST_SDK/VST3_SDK/build/VST3/Debug/again.vst3"
//#define BUNDLE_PATH @"/Users/koji/work/VST_SDK/VST3_SDK/build/VST3/Debug/channelcontext.vst3"
//#define BUNDLE_PATH @"/Users/koji/work/VST_SDK/VST3_SDK/build/VST3/Debug/adelay.vst3"
#define BUNDLE_PATH @"/Library/Audio/Plug-Ins/VST3/TAL-Chorus-LX.vst3"
//#define BUNDLE_PATH @"/Library/Audio/Plug-Ins/VST3/TDR VOS SlickEQ.vst3"

- (IBAction)testVST:(id)sender {
    NSBundle *bundle = [NSBundle bundleWithPath:BUNDLE_PATH];
    [bundle load];
    NSLog(@"bundle name = %@", bundle);
    
    tresult res = 0;
    
    {
        NSString *bundlePath = BUNDLE_PATH;
        NSURL *bundleURL = [NSURL fileURLWithPath:bundlePath];
        CFBundleRef cfBundle = NULL;
        cfBundle = CFBundleCreate(kCFAllocatorDefault, (CFURLRef)bundleURL);
        BundleEntryFunc entryFunc = (BundleEntryFunc)CFBundleGetFunctionPointerForName(cfBundle,CFSTR("bundleEntry"));
        if (!entryFunc){
            NSLog(@"Bundle does not export the required 'bundleEntry' function");
            return;
        }
        bool ret = entryFunc(cfBundle);
        NSLog(@"bundleEntry return %d", ret);
                                                                                       
        THEAPI func = (THEAPI)CFBundleGetFunctionPointerForName(cfBundle, CFSTR("GetPluginFactory"));
        if(!func){
            NSLog(@"GetPluginFactory() not found. Maybe not VST3 Plugin");
            return;
        }
        IPluginFactory *pluginFactory = func();

        if (!pluginFactory){
            NSLog(@"failed with get IPluginFactory");
            return;
        }
        
        NSLog(@"pluginFactory has %d classes.", pluginFactory->countClasses());
        
        int32 classNum = pluginFactory->countClasses();
        for (int i = 0; i < classNum; i++){
            PClassInfo classInfo;
            pluginFactory->getClassInfo(i, &classInfo);
            NSLog(@"class[%d],%s,category=%s", i, classInfo.name, classInfo.category);
            
            if (0 == strncmp(classInfo.category, kVstAudioEffectClass, strlen(kVstAudioEffectClass))){

                FUnknown *iUnknown = NULL;
                res = pluginFactory->createInstance(classInfo.cid, FUnknown::iid, (void **)&iUnknown);
                if (res != kResultOk){
                    NSLog(@"createInstance failed with %d", res);
                    continue;
                }
                
                Vst::IComponent *iComponent = NULL;
                res = iUnknown->queryInterface(Vst::IComponent::iid, (void **)&iComponent);
                if (res != kResultOk){
                    NSLog(@"queryIntarface for IComponent failed with %d", res);
                    continue;
                }
                
                res = iComponent->initialize(&hostApplication);
                if(res != kResultOk){
                    NSLog(@"failed with IComponent::initialize() %d", res);
                    continue;
                }
                
                res = iComponent->setActive(1);
                if(res != kResultOk){
                    NSLog(@"failed with IComponent::setActive(1). %d", res);
                }
                
                //get IAudioProcessor and do some stuff.
                Vst::IAudioProcessor *iAudioProcessor = NULL;
                res = iUnknown->queryInterface(Vst::IAudioProcessor::iid, (void **)(&iAudioProcessor));
                if (res != kResultOk){
                    NSLog(@"failed for queryInterface IAudioProcessor");
                    continue;
                }

                Vst::SpeakerArrangement sa = Vst::SpeakerArr::kStereo;
                res = iAudioProcessor->setBusArrangements(&sa, 1, &sa, 1);
                if (res != kResultOk){
                    NSLog(@"failed for setBusArrangements res = %d", res);
                    continue;
                }
                
                Vst::ProcessSetup processSetup;
                processSetup.maxSamplesPerBlock =32;
                processSetup.processMode = Vst::kRealtime;
                processSetup.sampleRate = 44100;
                processSetup.symbolicSampleSize = Vst::kSample32;
                res = iAudioProcessor->setupProcessing(processSetup);
                if (res != kResultOk){
                    NSLog(@"failed for setupProcessing res = %d", res);
                    continue;
                }
                
                //getControllerClassId()で取得したEditControllerのCIDを使ってcreateInstance()する
                TUID controllerClassId;
                Vst::IEditController *editController = NULL;
                bool needToInitializeEditController = false;
                res = iComponent->getControllerClassId(controllerClassId);
                if (res != kResultOk){
                    res = iComponent->queryInterface(Vst::IEditController::iid, (void **)&editController);
                    if (res != kResultOk){
                        NSLog(@"failed with getControllerClassId(fx) with %d", res);
                        continue;
                    }
                }else{
                    needToInitializeEditController = true;
                    res = pluginFactory->createInstance(controllerClassId, Vst::IEditController::iid,
                                                        (void **)&editController);
                }
                

                if (editController){
                    [self IEditorControllerObtained:editController
                                       withComponent:iComponent
                                    needToInitialize:needToInitializeEditController];
                    
                    g_audioProcessor = iAudioProcessor;
                }else{
                    NSLog(@"failed for createInstance for controller, IEditController. res = %d", res);
                    continue;
                }
 

            }else if (0 == strncmp(classInfo.category, kVstComponentControllerClass, strlen(kVstComponentControllerClass))){
                
//                FUnknown *iUnknown = NULL;
//                res = pluginFactory->createInstance(classInfo.cid, FUnknown::iid, (void **)&iUnknown);
//                if (iUnknown){
//                    Vst::IEditController *editController = NULL;
//                    res = iUnknown->queryInterface(Vst::IEditController::iid, (void **)&editController);
//                    if (editController){
//                        [self IEditorControllerObtained:editController];
//                    }
//                }
            }
        }
    }
}

//
-(void)IEditorControllerObtained:(Vst::IEditController *)editorController
withComponent:(Vst::IComponent *)component needToInitialize:(bool)needToInitialize{
    tresult res = 0;
    
    //適当なやつを渡す。
    if (needToInitialize){
        res = editorController->initialize(&hostApplication);
        if (res != kResultOk){
            NSLog(@"    failed with initialize");
            return;
        }else{
            NSLog(@"    OK to initialize");
        }
    }
    
    //適当なやつを渡す。
    res = editorController->setComponentHandler(&componentHandler);
    if(res != kResultOk){
        NSLog(@"    failed with setComponentHandler");
        return;
    }else{
        NSLog(@"    OK to setComponentHandler");
    }
    
    //IComponentとIEditControllerの相互接続を確立する
    Steinberg::FUnknownPtr<Vst::IConnectionPoint> connForComponent(component);
    Steinberg::FUnknownPtr<Vst::IConnectionPoint> connForEditController(editorController);
    
    if (connForComponent && connForEditController){
        connForComponent->connect(connForEditController);
        connForEditController->connect(connForComponent);
    }else{
        NSLog(@"    failed to get connection points");
    }
    
    Steinberg::MemoryStream stream;
    if(component->getState(&stream) != kResultOk){
        NSLog(@"    failed to get component state");
        return;
    }

    stream.seek(0, Steinberg::IBStream::IStreamSeekMode::kIBSeekSet, 0);
    res = editorController->setComponentState(&stream);
    
    //JUCE製のプラグインでは、setComponentState()の呼びだしで
    //kResultOKではなくkNotImplementedが返ってくることがある。
    if(res != kResultOk && res != kNotImplemented) {
        NSLog(@"    failed to set component state to IEditController");
        return;
    }
    
    //ここまではエラーなしで来ることを確認済み。
    int32 c = editorController->getParameterCount();
    NSLog(@"    has %d parameters",c);

    for (int i=0; i < c; i++){
        Vst::ParameterInfo paramInfo = Vst::ParameterInfo();
        res = editorController->getParameterInfo(i, paramInfo);

        NSString *title = [[NSString alloc] initWithCharacters:(const unichar *)paramInfo.title length:128];
        NSString *units = [[NSString alloc] initWithCharacters:(const unichar *)paramInfo.units length:128];
        Vst::ParamID paramId = paramInfo.id;
        Vst::ParamValue defNormalizedValue = paramInfo.defaultNormalizedValue;

        NSLog(@"    parameter[%d]:%@(%d)=%f%@", i, title, paramId,defNormalizedValue,units);
    }
    
    IPlugView *view = editorController->createView("editor");
    NSLog(@"    view = %p", view);

    if(view){
        res = view->isPlatformTypeSupported(kPlatformTypeNSView);
        NSLog(@"    isPlatformTypeSupported(NSView) res = %d", res);

        res = view->attached((__bridge void *)_pluginEditorSuperView, kPlatformTypeNSView);
        NSLog(@"    attached res = %d",res);
    }
}

@end
