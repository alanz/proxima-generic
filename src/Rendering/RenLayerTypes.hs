module Rendering.RenLayerTypes ( module Arrangement.ArrTypes
--                     , module RenTypesGTK
                     , module Rendering.RenTypes
                     , module Rendering.RenLayerTypes    ) where

import Common.CommonTypes
import Arrangement.ArrTypes
--import RenTypesGTK
import Rendering.RenTypes
import Data.IORef

data LocalStateRen = LocalStateRen { getViewedAreaRefRen :: IORef Rectangle
                                   }