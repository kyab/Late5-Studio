//
//  CEditorHost.hpp
//  Late5 Studio
//
//  Created by kyab on 2020/10/05.
//  Copyright © 2020 kyab. All rights reserved.
//

#ifndef CEditorHost_hpp
#define CEditorHost_hpp
#import <Cocoa/Cocoa.h>
#import <Foundation/Foundation.h>
#include <stdio.h>
#include "pluginterfaces/base/funknown.h"
#include "pluginterfaces/gui/iplugview.h"
#include "pluginterfaces/gui/iplugviewcontentscalesupport.h"
#include "pluginterfaces/vst/ivstaudioprocessor.h"
#include "pluginterfaces/vst/ivsteditcontroller.h"
#include "pluginterfaces/vst/vsttypes.h"
#include "pluginterfaces/vst/ivsthostapplication.h"
#include "pluginterfaces/vst/ivstunits.h"

#define _DEBUG
#include "public.sdk/source/vst/hosting/pluginterfacesupport.h"


#include <cstdio>
#include <iostream>

namespace Steinberg{
namespace Vst{


class MyComponentHandler : public Vst::IComponentHandler, public Vst::IComponentHandler2
{
public:
    MyComponentHandler();
    virtual ~MyComponentHandler();
    
    tresult PLUGIN_API beginEdit (Vst::ParamID id) override
    {
        NSLog(@"beginEdit called (%d)\n", id);
        return kNotImplemented;
    }
    tresult PLUGIN_API performEdit (Vst::ParamID id, Vst::ParamValue valueNormalized) override
    {
        NSLog(@"performEdit called (%d, %f)\n", id, valueNormalized);
        return kNotImplemented;
    }
    tresult PLUGIN_API endEdit (Vst::ParamID id) override
    {
        NSLog(@"endEdit called (%d)\n", id);
        return kNotImplemented;
    }
    tresult PLUGIN_API restartComponent (int32 flags) override
    {
        NSLog(@"restartComponent called (%d)\n", flags);
        return kNotImplemented;
    }
    
    tresult PLUGIN_API setDirty (TBool state) override {
        NSLog(@"setDirty called");
        return kNotImplemented;
    }
    
    tresult PLUGIN_API requestOpenEditor (FIDString name = Vst::ViewType::kEditor) override {
        NSLog(@"requestOpenEditor");
        return kNotImplemented;
    }
    
    tresult PLUGIN_API startGroupEdit() override {
        NSLog(@"startGroupEdit called");
        return kNotImplemented;
    }

    /** Finishes the group editing started by a \ref startGroupEdit (call after a \ref IComponentHandler::endEdit). */
    tresult PLUGIN_API finishGroupEdit () override {
        NSLog(@"finishGroupEdit");
        return kNotImplemented;
    }
    
     DECLARE_FUNKNOWN_METHODS

};



class HostApplication : public IHostApplication
{
public:
    HostApplication();
    virtual ~HostApplication() { FUNKNOWN_DTOR }


    //--- IHostApplication ---------------
    tresult PLUGIN_API getName (String128 name) SMTG_OVERRIDE;
    tresult PLUGIN_API createInstance (TUID cid, TUID _iid, void** obj) SMTG_OVERRIDE;
    
    DECLARE_FUNKNOWN_METHODS

    PlugInterfaceSupport* getPlugInterfaceSupport () const {
        NSLog(@"HostApplication::getPlugInterfaceSupport called");
        return mPlugInterfaceSupport;
        
    }
protected:
    IPtr<PlugInterfaceSupport> mPlugInterfaceSupport;
};


//class Message : public IMassage(){
//public:
//    Message();
//    
//}

}
}
#endif /* CEditorHost_hpp */
