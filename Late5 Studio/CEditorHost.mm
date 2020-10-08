//
//  CEditorHost.cpp
//  Late5 Studio
//
//  Created by kyab on 2020/10/05.
//  Copyright © 2020 kyab. All rights reserved.
//

#import "CEditorHost.h"

namespace Steinberg{
namespace Vst{


IMPLEMENT_REFCOUNT(MyComponentHandler)

MyComponentHandler::MyComponentHandler(){
    FUNKNOWN_CTOR
}

MyComponentHandler::~MyComponentHandler(){
    FUNKNOWN_DTOR
}

tresult PLUGIN_API MyComponentHandler::queryInterface (const char* _iid, void** obj)
{
    NSUUID *uuid = [[NSUUID alloc] initWithUUIDBytes:(const unsigned char *)_iid];
    NSLog(@"MyComponentHandler::queryInterface get called for TUID:%@", uuid.UUIDString);
    
    
    QUERY_INTERFACE (_iid, obj, IComponentHandler::iid, IComponentHandler);
    QUERY_INTERFACE (_iid, obj, IComponentHandler2::iid, IComponentHandler2);

    NSLog(@"failed ?");
    *obj = nullptr;
    return kResultFalse;
}


HostApplication::HostApplication ()
{
    FUNKNOWN_CTOR

    mPlugInterfaceSupport = owned (NEW PlugInterfaceSupport);
}

tresult PLUGIN_API HostApplication::getName (String128 name)
{
    NSLog(@"hogehoge");
    return kResultTrue;
}

tresult PLUGIN_API HostApplication::createInstance (TUID cid, TUID _iid, void** obj)
{
    NSLog(@"HostApplication::createInstance");
    FUID classID (FUID::fromTUID (cid));
    FUID interfaceID (FUID::fromTUID (_iid));
    if (classID == IMessage::iid && interfaceID == IMessage::iid)
    {
        NSLog(@"IMessage");
//        *obj = new HostMessage;
        return kResultTrue;
    }
    else if (classID == IAttributeList::iid && interfaceID == IAttributeList::iid)
    {
        NSLog(@"IAttributeList");
//        *obj = new HostAttributeList;
        return kResultTrue;
    }else{
        NSUUID *uuid = [[NSUUID alloc] initWithUUIDBytes:(const unsigned char *)cid];
        NSUUID *uuid2 = [[NSUUID alloc] initWithUUIDBytes:(const unsigned char *)_iid];
        NSLog(@"HostApplication::createInstance called for %@, %@", uuid.UUIDString, uuid2.UUIDString);
    }
    *obj = nullptr;
    return kResultFalse;
}

//-----------------------------------------------------------------------------
tresult PLUGIN_API HostApplication::queryInterface (const char* _iid, void** obj)
{
    NSUUID *uuid = [[NSUUID alloc] initWithUUIDBytes:(const unsigned char *)_iid];
    NSLog(@"HostApplication::queryInterface get called for TUID:%@", uuid.UUIDString);
    
    
    QUERY_INTERFACE (_iid, obj, FUnknown::iid, IHostApplication)
    QUERY_INTERFACE (_iid, obj, IHostApplication::iid, IHostApplication)

    if (mPlugInterfaceSupport && mPlugInterfaceSupport->queryInterface (iid, obj) == kResultTrue)
        return kResultOk;

    
    NSLog(@"failed ?");
    *obj = nullptr;
    return kResultFalse;
}

//-----------------------------------------------------------------------------
IMPLEMENT_REFCOUNT(HostApplication)


#include <algorithm>


//-----------------------------------------------------------------------------
PlugInterfaceSupport::PlugInterfaceSupport ()
{
    // add minimum set

    //---VST 3.0.0--------------------------------
    addPlugInterfaceSupported (IComponent::iid);
    addPlugInterfaceSupported (IAudioProcessor::iid);
    addPlugInterfaceSupported (IEditController::iid);
    addPlugInterfaceSupported (IConnectionPoint::iid);

    addPlugInterfaceSupported (IUnitInfo::iid);
    addPlugInterfaceSupported (IUnitData::iid);
    addPlugInterfaceSupported (IProgramListData::iid);

    //---VST 3.0.1--------------------------------
    addPlugInterfaceSupported (IMidiMapping::iid);

    //---VST 3.1----------------------------------
    addPlugInterfaceSupported (IEditController2::iid);

    /*
    //---VST 3.0.2--------------------------------
    addPlugInterfaceSupported (IParameterFinder::iid);

    //---VST 3.1----------------------------------
    addPlugInterfaceSupported (IAudioPresentationLatency::iid);

    //---VST 3.5----------------------------------
    addPlugInterfaceSupported (IKeyswitchController::iid);
    addPlugInterfaceSupported (IContextMenuTarget::iid);
    addPlugInterfaceSupported (IEditControllerHostEditing::iid);
    addPlugInterfaceSupported (IXmlRepresentationController::iid);
    addPlugInterfaceSupported (INoteExpressionController::iid);

    //---VST 3.6.5--------------------------------
    addPlugInterfaceSupported (ChannelContext::IInfoListener::iid);
    addPlugInterfaceSupported (IPrefetchableSupport::iid);
    addPlugInterfaceSupported (IAutomationState::iid);

    //---VST 3.6.11--------------------------------
    addPlugInterfaceSupported (INoteExpressionPhysicalUIMapping::iid);

    //---VST 3.6.12--------------------------------
    addPlugInterfaceSupported (IMidiLearn::iid);

    //---VST 3.7-----------------------------------
    addPlugInterfaceSupported (IProcessContextRequirements::iid);
    addPlugInterfaceSupported (IParameterFunctionName::iid);
    addPlugInterfaceSupported (IProgress::iid);
    */
}

//-----------------------------------------------------------------------------
tresult PLUGIN_API PlugInterfaceSupport::isPlugInterfaceSupported (const TUID _iid)
{
    auto uid = FUID::fromTUID (_iid);
    if (std::find (mFUIDArray.begin (), mFUIDArray.end (), uid) != mFUIDArray.end ())
        return kResultTrue;
    return kResultFalse;
}

//-----------------------------------------------------------------------------
void PlugInterfaceSupport::addPlugInterfaceSupported (const TUID _iid)
{
    mFUIDArray.push_back (FUID::fromTUID (_iid));
}

//-----------------------------------------------------------------------------
bool PlugInterfaceSupport::removePlugInterfaceSupported (const TUID _iid)
{
    return std::remove (mFUIDArray.begin (), mFUIDArray.end (), FUID::fromTUID (_iid)) !=
           mFUIDArray.end ();
}



}
}
