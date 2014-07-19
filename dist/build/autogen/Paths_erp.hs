module Paths_erp (
    version,
    getBinDir, getLibDir, getDataDir, getLibexecDir,
    getDataFileName, getSysconfDir
  ) where

import qualified Control.Exception as Exception
import Data.Version (Version(..))
import System.Environment (getEnv)
import Prelude

catchIO :: IO a -> (Exception.IOException -> IO a) -> IO a
catchIO = Exception.catch


version :: Version
version = Version {versionBranch = [0,0,0,2], versionTags = []}
bindir, libdir, datadir, libexecdir, sysconfdir :: FilePath

bindir     = "C:\\Users\\magocoal\\AppData\\Roaming\\cabal\\bin"
libdir     = "C:\\Users\\magocoal\\AppData\\Roaming\\cabal\\i386-windows-ghc-7.6.3\\erp-0.0.0.2"
datadir    = "C:\\Users\\magocoal\\AppData\\Roaming\\cabal\\i386-windows-ghc-7.6.3\\erp-0.0.0.2"
libexecdir = "C:\\Users\\magocoal\\AppData\\Roaming\\cabal\\erp-0.0.0.2"
sysconfdir = "C:\\Users\\magocoal\\AppData\\Roaming\\cabal\\etc"

getBinDir, getLibDir, getDataDir, getLibexecDir, getSysconfDir :: IO FilePath
getBinDir = catchIO (getEnv "erp_bindir") (\_ -> return bindir)
getLibDir = catchIO (getEnv "erp_libdir") (\_ -> return libdir)
getDataDir = catchIO (getEnv "erp_datadir") (\_ -> return datadir)
getLibexecDir = catchIO (getEnv "erp_libexecdir") (\_ -> return libexecdir)
getSysconfDir = catchIO (getEnv "erp_sysconfdir") (\_ -> return sysconfdir)

getDataFileName :: FilePath -> IO FilePath
getDataFileName name = do
  dir <- getDataDir
  return (dir ++ "\\" ++ name)
