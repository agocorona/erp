module ErpModel (
        createRequest, 
        createResponse,
        delete,
        getResponseEntity,
        createCloseConnectionResponse,
        createNextSequenceResponse,
        protocolVersion,
        loginEmail,
        exists,
        supportedVersions,
        QueryParty(..),
        InsertParty(..),
        DeleteParty(..),
        QueryCompany(..),
        InsertCompany(..),
        InsertResponse(..),
        InsertRequest(..),
        InsertLogin(..),
        DeleteLogin(..),
        QueryLogin(..),
        QueryCategory(..),
        InsertCategory(..),
        sendTextData,
        sendError, 
        sendMessage,
        modelModuleName,
        nextRequestID,
        updateResponseID,
        updateSequenceNumber,
        getRequestEmail,
        getRequestEntity,
        initializeDatabase,
        disconnect,
        Request(..),
        RequestType(..),
        Response(..),
        GetDatabase(..),
        getSequenceNumber
        )        
        where

import System.Log.Logger
import Data.Maybe
import Control.Monad.State
import Control.Monad.Reader
import Control.Exception

import System.Log.Logger
import System.Log.Handler.Syslog
import System.Log.Handler.Simple
import System.Log.Handler (setFormatter)
import System.Log.Formatter

import qualified Control.Applicative as C
import qualified Data.Acid as A
import Data.Acid.Remote
import Data.SafeCopy
import Data.Typeable

import qualified Data.Map as M
import qualified Data.Set as S
import qualified Data.Aeson as J
import qualified Data.Text.Lazy.Encoding as E
import qualified Data.Text as T
import qualified Data.Text.Lazy as L
import qualified Data.Text.IO as TIO
import qualified Network.WebSockets.Connection as WS
import Data.Dynamic
import Data.Time.Clock
import GHC.Generics
import qualified ErpError as ErEr
import qualified Login as Lo
import qualified SystemSequence as SSeq
import qualified Company as Co
import qualified Product as Pr
import qualified Production as Prod
import qualified Project as Proj
import qualified Stock as St
import qualified Shipment as Sh
import qualified Purchase as Pu
import qualified Sale as Sa
import qualified Forecast as Fo
import qualified Timesheet as Ts
import qualified SystemSequence as Seq
import qualified ErpError as ErEr
data LoginExists = LoginExists deriving (Show, Generic, Typeable, Eq, Ord)
data LoginStaleException = LoginStaleException deriving (Show, Generic, Typeable, Eq, Ord)
data CategoryExists = CategoryExists deriving (Show, Generic, Typeable, Eq, Ord)
data LoginNotFound = LoginNotFound deriving (Show, Generic, Typeable, Eq, Ord)
data InvalidResponse = InvalidResponse deriving (Show, Generic, Typeable, Eq, Ord)

instance Exception InvalidResponse

type Deleted = Bool

{-Note about the versioning scheme:.  The versioning scheme is to support 
a form of an optimistic lock. Server returns the next valid request id to a client. 
Any request that comes with a value less than the last request id is considered to be
stale and the stale request is  returned to the client as part of an error. -}


data ErpModel = ErpModel
                {
                    login :: Lo.Login,
                    partySet :: S.Set Co.Party,
                    companySet :: S.Set Co.Company,
                    categorySet :: S.Set Co.Category,
                    deleted :: Deleted,
                    requests :: [Request],
                    responses :: [Response]                
                } deriving (Show, Generic, Typeable, Eq, Ord)


nextRequest :: [Request] -> Integer
nextRequest [] = 1
nextRequest (h:t) = (requestID h) + 1
-- The next request id for this model.

nextRequestID :: ErpModel -> Request -> SSeq.ID
nextRequestID aModel aRequest = nextRequest (requests aModel)

delete anErpModel = anErpModel {deleted = True}
{-- A given email id can be tied to only a single erp model,
 though a given model can be associated with multiple email ids--}
data Database = Database ! (M.Map String ErpModel)
     deriving (Show, Generic, Typeable, Eq, Ord)
{-- Query and retrieve are similar, but the distinction that we are trying to make 
here is that one is a database operation, while the other is a query in general??--}
data RequestType = Create | Retrieve | Update | Delete | Query | Command 
    deriving (Show, Generic, Typeable, Eq, Ord)
type RequestEntity = String
type ProtocolVersion = String
type ID = SSeq.ID
data Request = Request {
    requestID :: ID,
    requestType :: RequestType,
    requestVersion :: ProtocolVersion,
    requestEntity :: RequestEntity,
    emailId :: String,
    requestPayload :: L.Text} deriving(Show, Generic, Typeable, Eq, Ord)

createRequest anID aVersion entity aType  emailId aPayload = 
    Request anID aVersion entity aType emailId aPayload

data Response = Response {
    responseID :: ID,
    requestIDToUse :: ID,
    responseVersion :: ProtocolVersion,
    incomingRequest :: Maybe Request,
    responsePayload :: L.Text } deriving (Show, Generic, Typeable, Eq, Ord)

createResponse anID nextIDToUse responseVersion request payload =
    Response anID nextIDToUse responseVersion request payload


updateSequenceNumber :: Response -> Request -> Request
updateSequenceNumber aResponse aRequest = aRequest {requestID = getSequenceNumber aResponse}

updateResponseID :: Response -> ErEr.ErpError ErEr.ModuleError Response -> 
    ErEr.ErpError ErEr.ModuleError Response

updateResponseID newResponse (ErEr.Success oldResponse) = 
        ErEr.Success oldResponse {responseID = responseID newResponse 
        , requestIDToUse = requestIDToUse newResponse}

updateResponseID newResponse (ErEr.Error x ) = ErEr.Error x

-- Unwrap the request type from the response
getResponseEntity :: Response -> Maybe RequestEntity
getResponseEntity aResponse = do
    incomingRequest <- incomingRequest aResponse
    return $ getRequestEntity incomingRequest

unwrapRequest :: Response -> Maybe Request
unwrapRequest = incomingRequest 


createCloseConnectionResponse r = Response (requestID r) (requestID r)
                                                            protocolVersion
                                                            (Just r) 
                                                            $ L.pack $ show r
-- Create a new response with the next id.
createNextSequenceResponse emailId c anID = Response anID  anID protocolVersion c 
            $ L.pack $ show anID

getSequenceNumber aResponse = requestIDToUse aResponse
getRequestEmail aRequest = emailId aRequest
getRequestEntity aRequest = requestEntity aRequest


-- The current protocol build version.
-- This needs to be validated before processing
-- a request.We should get the build version,
-- from the build instead of using a string as below.
-- Version naming protocol should be similar to
-- what most systems do today, so basic
-- increments will still compare.
-- We need to maintain some amount
-- of backward compatibility, though,
-- that is probably debatable?
protocolVersion :: ProtocolVersion
protocolVersion = "0.0.0.1"

-- ID is a string read and written from an integer



emptyModel = ErpModel {
                partySet = S.empty,
                categorySet = S.empty,
                companySet = S.empty,
                login = Lo.empty,
                requests= [],
                responses = [],
                deleted = False
              }


loginEmail :: ErpModel -> Lo.Email 
loginEmail anErpModel = Lo.getLoginEmail $ login anErpModel

exists :: Co.Category -> Maybe ErpModel -> Bool
exists aKey Nothing = False
exists aKey (Just e) = (S.member aKey $ categorySet e)


supportedVersions :: ErpModel -> S.Set ProtocolVersion
supportedVersions aModel = 
    let 
        reqVersions = map  (\x -> requestVersion x)   ( requests aModel)
        resVersions  = map   (\x -> responseVersion x)  (responses aModel)
    in 
        S.fromList reqVersions

--A given model can handle multiple companies 
updateCompany :: ErpModel -> Co.Company -> ErpModel
updateCompany aModel aCompany = aModel {companySet = S.insert aCompany (companySet aModel)}

-- Delete a company from the model
deleteCompany :: ErpModel -> Co.Company -> ErpModel 
deleteCompany aModel aCompany = aModel {companySet = S.delete aCompany (companySet aModel)}

updateCategory :: ErpModel -> Co.Category -> ErpModel
updateCategory aModel aCategory = 
    aModel{ categorySet = S.insert aCategory (categorySet aModel)}

updateParty :: ErpModel -> Co.Party -> ErpModel
updateParty aModel aParty = 
    aModel {partySet = S.insert aParty (partySet aModel)}


-- Query a party by the email id, name 
-- and the geographical location
-- The assumption being that a given party and 
-- location will be unique.
queryParty :: String -> String -> Co.GeoLocation -> 
    A.Query Database (ErEr.ErpError ErEr.ModuleError Co.Party)
queryParty aLogin aName aLocation  =
    do
        Database db <- ask
        erp <- return $ M.lookup aLogin db
        case erp of
            Nothing -> throw Co.CompanyNotFound
            Just x -> return $ Co.findParty (aName, aLocation) (partySet x)


insertParty :: String -> Co.Party -> A.Update Database ()
insertParty aLogin p =
    do
        Database db <- get
        erp <- return $ M.lookup aLogin db
        case erp of
            Just exists -> put(Database (M.insert aLogin (updateParty exists p) db))
            _ -> return ()

deleteParty :: String -> Co.Party -> A.Update Database ()
deleteParty aLogin aParty = do
    Database db <- get
    erp <- return $ M.lookup aLogin db
    case erp of
        Just found -> put (Database (M.insert aLogin (delP2 aParty found) db))
        _ -> return ()
    where
        delP2 aParty model = model {partySet = S.delete aParty (partySet model)}


insertCompany :: String -> Co.Company -> A.Update Database() 
insertCompany aLogin aCompany = do
    Database db <- get
    erp <- return $ M.lookup aLogin db
    case erp of 
        Just exists -> put $ Database $ M.insert aLogin (updateCompany exists aCompany) db
        Nothing -> return ()

queryCompany :: String -> Co.Party -> 
    A.Query Database (ErEr.ErpError ErEr.ModuleError Co.Company)
queryCompany aLogin aParty =
    do
        Database db <- ask
        erp <- return $ M.lookup aLogin db
        case erp of
            Nothing -> return $ ErEr.createErrorS "ErpModel" "EM001" 
                        $ "Party not found " ++ show aParty ++ " for " ++ aLogin
            Just x -> return $ Co.findCompany aParty (companySet x)


insertResponse :: Response -> A.Update Database (ErEr.ErpError ErEr.ModuleError Response)
insertResponse  aResponse = 
    let 
        update aModel = aModel {responses = aResponse : (responses aModel)}
    in
    do
        Database db <- get
        iRequest <- return $ incomingRequest aResponse
        case iRequest of
            Just iR -> 
                        let erp = M.lookup (emailId iR) db
                        in
                            do
                                case erp of
                                    Just m -> do
                                            put (Database $ M.insert (emailId iR) (update m) db)
                                            return $ ErEr.createSuccess aResponse
                                    Nothing -> do
                                            put (Database $ M.insert (emailId iR) (update emptyModel) db)
                                            return $ ErEr.createErrorS "ErpModel" "EM002"$ show aResponse
            Nothing -> return $ ErEr.createErrorS "ErpModel" "EM002" $ "Could not parse request " ++ (show aResponse)


insertRequest ::  Request -> A.Update Database ()
insertRequest aRequest =  
    let 
        update model = model {requests = aRequest : (requests model) }
    in
    do
        Database db <- get
        email <- return $ emailId aRequest
        incomingRequestType <- return $ (requestEntity aRequest)
        let erp = M.lookup email db
        case erp of
            Just m -> 
                    if incomingRequestType /= "Login" then
                        put (Database $ M.insert email (update m) db)
                    else
                        put (Database $ M.insert email m db)

            Nothing -> put (Database $ M.insert email (update emptyModel) db)


insertLogin :: String -> Request -> Lo.Login -> A.Update Database ()
insertLogin aString r aLogin =
    do
        Database db <- get
        loginErp <- return $ emptyModel {login = aLogin}
        put (Database (M.insert aString loginErp db))

deleteLogin :: String -> A.Update Database ()
deleteLogin aString  =
    do
        Database db <- get
        loginErp <- return $ M.lookup aString db
        case loginErp of
            Nothing -> return ()            
            Just x -> put (Database (M.insert aString (delete x) db))



queryLogin :: String -> A.Query  Database (Maybe Lo.Login)
queryLogin aLogin =
    do
        Database db <- ask
        erp <- return $ M.lookup aLogin db
        case erp of
            Just erp -> return $ Just $ login erp
            _   -> return Nothing


queryCategory :: String -> Co.Category -> A.Query  Database(Bool)
-- qbe -> query by example
queryCategory aLogin qbe =
    do
       Database db <- ask
       return $ exists qbe $ M.lookup aLogin db

insertCategory :: String -> Co.Category -> A.Update Database ()
insertCategory aLogin c@(Co.Category aCatName) =
    do
        Database db <- get
        erp <- return $ M.lookup aLogin db
        case erp of
            Just exists -> put(Database (M.insert aLogin (updateCategory exists c) db))
            _       -> return()


getDatabase :: String -> A.Query Database (Maybe ErpModel)
getDatabase userEmail = do
        Database db <- ask
        return $ M.lookup userEmail db

   
$(A.makeAcidic ''Database [
    'queryLogin, 'insertLogin,
    'deleteLogin, 'queryCategory, 'insertCategory
            , 'getDatabase
            , 'insertRequest
            , 'insertResponse
            , 'queryParty
            , 'insertParty
            , 'deleteParty
            , 'queryCompany
            , 'insertCompany ])


initializeDatabase  dbLocation = A.openLocalStateFrom dbLocation $ Database M.empty
disconnect acid  = do
        infoM modelModuleName "Closing acid state"
        A.closeAcidState acid
        return ()



sendTextData :: WS.Connection -> L.Text -> IO()
sendTextData connection aText = WS.sendTextData connection aText

sendMessage :: WS.Connection -> ErEr.ErpError ErEr.ModuleError Response-> IO()
sendMessage connection (ErEr.Success aResponse) =
    WS.sendTextData connection $ J.encode aResponse
sendMesssage connection (ErEr.Error aModuleError) =
    WS.sendTextData connection $ J.encode aModuleError

sendError :: WS.Connection -> Maybe Request -> L.Text -> IO()
sendError connection request aMessage = 
    let 
        response = Response (SSeq.errorID) (SSeq.errorID) protocolVersion request aMessage
    in
        WS.sendTextData connection $ J.encode response


modelModuleName :: String
modelModuleName = "ErpModel"



$(deriveSafeCopy 0 'base ''Database)
$(deriveSafeCopy 0 'base ''ErpModel)
$(deriveSafeCopy 0 'base ''Request)
$(deriveSafeCopy 0 'base ''Response)
$(deriveSafeCopy 0 'base ''RequestType)


instance J.ToJSON RequestType
instance J.FromJSON RequestType
instance J.ToJSON Request
instance J.FromJSON Request
instance J.ToJSON ErpModel
instance J.FromJSON ErpModel
instance J.ToJSON Response
instance J.FromJSON Response
