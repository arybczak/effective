{-# LANGUAGE CPP #-}

module Effectful.Plugin.Fundep.Stuff
  ( EffectfulStuff (..)
  , LookupState (..)
  , polysemyStuff
  ) where

import Data.Kind (Type)
import GHC (Name, Class, TyCon, mkModuleName)
import GHC.TcPluginM.Extra (lookupModule, lookupName)
#if __GLASGOW_HASKELL__ >= 900
import GHC.Data.FastString (fsLit)
import GHC.Types.Name.Occurrence (mkTcOcc)
import GHC.Tc.Plugin (TcPluginM, tcLookupClass, tcLookupTyCon, unsafeTcPluginTcM)
import GHC.Plugins (getDynFlags)
import GHC.Unit.State (lookupModuleWithSuggestions, LookupResult (..), UnitState)
import GHC.Utils.Outputable (text, (<+>), ($$))
#if __GLASGOW_HASKELL__ >= 902
import GHC.Tc.Plugin (getTopEnv)
import GHC.Utils.Panic (pprPanic)
import GHC.Driver.Env (hsc_units)
#else
import GHC.Plugins (unitState)
import GHC.Utils.Outputable(pprPanic)
#endif
#else
import FastString (fsLit)
import OccName (mkTcOcc)
import TcPluginM (TcPluginM, tcLookupClass, tcLookupTyCon, unsafeTcPluginTcM)
import GhcPlugins (getDynFlags)
import Packages (lookupModuleWithSuggestions, LookupResult (..))
import Outputable (pprPanic, text, (<+>), ($$))
#endif



------------------------------------------------------------------------------
-- | All of the things from "polysemy" that we need access to in the plugin.
-- When @l ~ 'Locations@, each of these is just a pair of strings. When @l
-- ~ 'Things@, it's actually references to the stuff.
data EffectfulStuff (l :: LookupState) = EffectfulStuff
  { findClass         :: ThingOf l Class
  , semTyCon          :: ThingOf l TyCon
  }


------------------------------------------------------------------------------
-- | All of the things we need to lookup.
polysemyStuffLocations :: EffectfulStuff 'Locations
polysemyStuffLocations = EffectfulStuff
  { findClass = ("Effectful.Internal.Effect", ":>")
  , semTyCon  = ("Effectful.Internal.Monad",       "Eff")
  }

#if __GLASGOW_HASKELL__ >= 900
------------------------------------------------------------------------------
-- | GHC-version-dependent access of the UnitState
getUnitState :: TcPluginM UnitState
getUnitState = do
#if __GLASGOW_HASKELL__ >= 902
  topState <- getTopEnv
  return (hsc_units topState)
#else
  dflags <- unsafeTcPluginTcM getDynFlags
  return (unitState dflags)
#endif
#endif

------------------------------------------------------------------------------
-- | Lookup all of the 'EffectfulStuff'.
polysemyStuff :: TcPluginM (EffectfulStuff 'Things)
polysemyStuff = do
#if __GLASGOW_HASKELL__ >= 900
  theUnitState <- getUnitState
#else
  dflags <- unsafeTcPluginTcM getDynFlags
#endif
  let error_msg = pprPanic "effectful-plugin"
          $ text ""
         $$ text "--------------------------------------------------------------------------------"
         $$ text "`effectful-plugin` is loaded, but"
        <+> text "`effectful` isn't available as a package."
         $$ text "Probable fix: add `effectful` to your cabal `build-depends`"
         $$ text "--------------------------------------------------------------------------------"
         $$ text ""
  case lookupModuleWithSuggestions
#if __GLASGOW_HASKELL__ >= 900
    theUnitState
#else
    dflags
#endif
    (mkModuleName "Effectful")
    Nothing of
    LookupHidden _ _ -> error_msg
    LookupNotFound _ -> error_msg
#if __GLASGOW_HASKELL__ >= 806
    LookupUnusable _ -> error_msg
#endif
    _                -> pure ()

  let EffectfulStuff a b = polysemyStuffLocations
  EffectfulStuff <$> doLookup a
                <*> doLookup b


------------------------------------------------------------------------------
-- | Data kind for 'ThingOf'.
data LookupState
  = Locations
  | Things


------------------------------------------------------------------------------
-- | HKD indexed by the 'LookupState'; used by 'EffectfulStuff'.
type family ThingOf (l :: LookupState) (a :: Type) :: Type where
  ThingOf 'Locations _ = (String, String)
  ThingOf 'Things    a = a


------------------------------------------------------------------------------
-- | Things that can be found in a 'TcPluginM' environment.
class CanLookup a where
  lookupStrategy :: Name -> TcPluginM a

instance CanLookup Class where
  lookupStrategy = tcLookupClass

instance CanLookup TyCon where
  lookupStrategy = tcLookupTyCon


------------------------------------------------------------------------------
-- | Transform a @'ThingOf' 'Locations@ into a @'ThingOf' 'Things@.
doLookup :: CanLookup a => ThingOf 'Locations a -> TcPluginM (ThingOf 'Things a)
doLookup (mdname, name) = do
  md <- lookupModule (mkModuleName mdname) $ fsLit "effectful"
  nm <- lookupName md $ mkTcOcc name
  lookupStrategy nm
