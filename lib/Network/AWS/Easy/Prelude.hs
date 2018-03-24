{-|
Module      : Network.AWS.Easy.Prelude
Description : Re-exports of some commonly used @amazonka@ functions
Copyright   : (C) Richard Cook, 2018
License     : MIT
Maintainer  : rcook@rcook.org
Stability   : experimental
Portability : portable

This module provides re-exports of most commonly used @amazonka@ functions as well as lens and error-handling functions.
-}

module Network.AWS.Easy.Prelude
    ( (^.)
    , (&)
    , (.~)
    , _ServiceError
    , AsError
    , Credentials(..)
    , Region(..)
    , ServiceError
    , await
    , hasCode
    , hasStatus
    , send
    , sinkBody
    , toText
    ) where

import           Control.Lens ((^.), (&), (.~))
import           Network.AWS
                    ( _ServiceError
                    , AsError
                    , Credentials(..)
                    , Region(..)
                    , ServiceError
                    , await
                    , send
                    , sinkBody
                    )
import           Network.AWS.Data (toText)
import           Network.AWS.Error
                    ( hasCode
                    , hasStatus
                    )
