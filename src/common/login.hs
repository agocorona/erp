{-- 
    .. Notation is important as per this link:
    exporting data constructors: http://en.wikibooks.org/wiki/Haskell/Modules.
--}
module Login(Login (..), 
            Email,
            Name)
    where

import Control.Monad.State
import Control.Monad.Reader
import qualified Control.Applicative as C
import qualified Data.Acid as A
import Data.Acid.Remote
import Data.SafeCopy
import Data.Typeable
import qualified Data.Map as M
import qualified Data.Aeson as J
import qualified Data.Text.Lazy.Encoding as E
import qualified Data.Text.Lazy as L
import Data.Time.Clock
import GHC.Generics

type Email = String
type Name = String

data Login = Login{email :: Email, verified :: Bool} 
    deriving (Show, Generic, Typeable, Eq, Ord)
instance J.ToJSON Login
instance J.FromJSON Login


$(deriveSafeCopy 0 'base ''Login)
