-- | Lifted functions from "Data.ByteString.Lazy" that are related to standard
-- streams.
-- Like the original module, you probably want to import this module qualified
-- to avoid name clashes with the functions provided by "Prelude", e.g.:
--
-- > import Data.ByteString.Lazy (ByteString)
-- > import qualified Data.ByteString.Lazy as LBS
-- > import qualified Effectful.Console.ByteString.Lazy.Static as ELBS
--
module Effectful.Console.ByteString.Lazy.Static
  ( -- * Effect
    module Effectful.Console.Static

    -- * Standard input and output
  , getContents
  , putStr
  , interact
  ) where

import Prelude hiding
  ( getContents
  , interact
  , putStr
  )

import Data.ByteString.Lazy (ByteString)
import qualified Data.ByteString.Lazy as LBS

import Effectful
import Effectful.Console.Static
import Effectful.Dispatch.Static

-- | Lifted 'LBS.getContents'.
getContents :: Console :> es => Eff es ByteString
getContents = unsafeEff_ LBS.getContents

-- | Lifted 'LBS.putStr'.
putStr :: Console :> es => ByteString -> Eff es ()
putStr = unsafeEff_ . LBS.putStr

-- | Lifted 'LBS.interact'.
interact :: Console :> es => (ByteString -> ByteString) -> Eff es ()
interact = unsafeEff_ . LBS.interact
