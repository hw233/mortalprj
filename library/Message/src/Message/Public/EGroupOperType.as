// **********************************************************************
//
// Copyright (c) 2003-2009 CDE, Inc. All rights reserved.
//
// This copy of Cde is licensed to you under the terms described in the
// CDE_LICENSE file included in this distribution.
//
// **********************************************************************

// CDE version 1.0.1

package Message.Public{

import Framework.Serialize.SerializeStream;
import Framework.Util.StringFun;
import Framework.Util.Exception;
import Framework.MQ.*;
import Framework.Holder.*;

import Engine.RMI.*;
import flash.utils.ByteArray;

import flash.utils.Dictionary;



public class EGroupOperType
{
    public var __value : int;

    public static const _EGroupOperTypeApply : int = 0;
    public static const _EGroupOperTypeInvite : int = 1;
    public static const _EGroupOperTypeAgree : int = 2;
    public static const _EGroupOperTypeReject : int = 3;
    public static const _EGroupOperTypeRejectApply : int = 4;
    public static const _EGroupOperTypeRejectInvite : int = 5;

    public static function convert( val : int ) : EGroupOperType
    {
        return new EGroupOperType( val );
    }

    public function value() : int
    {
        return __value;
    }

    public function EGroupOperType( val : int )
    {
        __value = val;
    }

    public function __write( __os : SerializeStream ) : void
    {
        __os.writeByte( __value );
    }

    public static function __read( __is : SerializeStream ) : EGroupOperType
    {
        var __v : int = __is.readByte();
        if(__v < 0 || __v >= 6)
        {
            throw new MarshalException();
        }
        return EGroupOperType.convert(__v);
    }
}
}
