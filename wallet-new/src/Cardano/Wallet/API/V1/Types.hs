{-# LANGUAGE DeriveGeneric              #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE KindSignatures             #-}
{-# LANGUAGE OverloadedStrings          #-}
{-# LANGUAGE ScopedTypeVariables        #-}
{-# LANGUAGE TemplateHaskell            #-}
{-# LANGUAGE TypeFamilies               #-}

module Cardano.Wallet.API.V1.Types (
  -- * Swagger & REST-related types
    ExtendedResponse (..)
  , Metadata (..)
  , Page(..)
  , PerPage(..)
  , maxPerPageEntries
  , defaultPerPageEntries
  , OneOf (..)
  , PasswordUpdate (..)
  , AccountUpdate (..)
  , Update
  , New
  -- * Error handling
  , WalletError (..)
  -- * Domain-specific types
  , Wallet (..)
  , NewWallet (..)
  , WalletUpdate (..)
  , WalletId (..)
  , Address (..)
  , Account (..)
  , AccountId
  -- * Payments
  , Payment (..)
  , Transaction (..)
  , EstimatedFees (..)
  -- * Updates
  , WalletSoftwareUpdate (..)
  ) where

import           Universum

import           Data.Aeson
import           Data.Aeson.TH
import           Data.Text              (Text)
import           GHC.Generics           (Generic)
import qualified Serokell.Aeson.Options as Serokell
import           Test.QuickCheck
import           Web.HttpApiData

--
-- Swagger & REST-related types
--

-- | A `Page` is used in paginated endpoints to request access to a particular
-- subset of a collection.
newtype Page = Page Int
             deriving (Show, Eq, Ord, Num)

deriveJSON Serokell.defaultOptions ''Page

instance Arbitrary Page where
  arbitrary = Page <$> fmap getPositive arbitrary

instance FromHttpApiData Page where
    parseQueryParam qp = case parseQueryParam qp of
        Right (p :: Int) | p < 1 -> Left "A page number cannot be less than 1."
        Right (p :: Int) -> Right (Page p)
        Left e           -> Left e

instance ToHttpApiData Page where
    toQueryParam (Page p) = fromString (show p)

-- | A `PerPage` is used to specify the number of entries which should be returned
-- as part of a paginated response.
newtype PerPage = PerPage Int
                deriving (Show, Eq, Num, Ord)

deriveJSON Serokell.defaultOptions ''PerPage

-- | The maximum number of entries a paginated request can return on a single call.
-- This value is currently arbitrary and it might need to be tweaked down to strike
-- the right balance between number of requests and load of each of them on the system.
maxPerPageEntries :: Int
maxPerPageEntries = 500

-- | If not specified otherwise, a default number of 10 entries from the collection will
-- be returned as part of each paginated response.
defaultPerPageEntries :: Int
defaultPerPageEntries = 10

instance Arbitrary PerPage where
  arbitrary = PerPage <$> choose (1, 500)

instance FromHttpApiData PerPage where
    parseQueryParam qp = case parseQueryParam qp of
        Right (p :: Int) | p < 1 -> Left "per_page should be at least 1."
        Right (p :: Int) | p > maxPerPageEntries ->
                           Left $ fromString $ "per_page cannot be greater than " <> show maxPerPageEntries <> "."
        Right (p :: Int) -> Right (PerPage p)
        Left e           -> Left e

instance ToHttpApiData PerPage where
    toQueryParam (PerPage p) = fromString (show p)

-- | Extra information associated with an HTTP response.
data Metadata = Metadata
  { metaTotalPages   :: Int     -- ^ The total pages returned by this query.
  , metaPage         :: Page    -- ^ The current page number (index starts at 1).
  , metaPerPage      :: PerPage -- ^ The number of entries contained in this page.
  , metaTotalEntries :: Int     -- ^ The total number of entries in the collection.
  } deriving (Show, Eq, Generic)

deriveJSON Serokell.defaultOptions ''Metadata

instance Arbitrary Metadata where
  arbitrary = Metadata <$> fmap getPositive arbitrary
                       <*> arbitrary
                       <*> arbitrary
                       <*> fmap getPositive arbitrary

-- | An `ExtendedResponse` allows the consumer of the API to ask for
-- more than simply the result of the RESTful endpoint, but also for
-- extra informations like pagination parameters etc.
data ExtendedResponse a = ExtendedResponse
  { extData :: a        -- ^ The wrapped domain object.
  , extMeta :: Metadata -- ^ Extra metadata to be returned.
  } deriving (Show, Eq, Generic)

deriveJSON Serokell.defaultOptions ''ExtendedResponse

instance Arbitrary a => Arbitrary (ExtendedResponse a) where
  arbitrary = ExtendedResponse <$> arbitrary <*> arbitrary

-- | Type introduced to mimick Swagger 3.0 'oneOf' keyword. It's used to model responses whose body can change
-- depending from some query or header parameters. In this context, this represents an HTTP Response which can
-- return the wrapped object OR the ExtendedResponse.
newtype OneOf a b = OneOf { oneOf :: Either a b } deriving (Show, Eq, Generic)

instance (ToJSON a, ToJSON b) => ToJSON (OneOf a b) where
  toJSON (OneOf (Left x))  = toJSON x -- Simply "unwrap" the type.
  toJSON (OneOf (Right x)) = toJSON x -- Simply "unwrap" the type.

instance (Arbitrary a, Arbitrary b) => Arbitrary (OneOf a b) where
  arbitrary = OneOf <$> oneof [ fmap Left  (arbitrary :: Gen a)
                              , fmap Right (arbitrary :: Gen b)]

--
-- Error handling
--

-- | Models a Wallet Error as a Jsend <https://labs.omniti.com/labs/jsend> response.
data WalletError = WalletError
  { errCode    :: !Int
  , errMessage :: Text
  } deriving (Show, Eq, Generic)

instance ToJSON WalletError where
    toJSON WalletError{..} = object [ "code"    .= toJSON errCode
                                    , "status"  .= String "error"
                                    , "message" .= toJSON errMessage
                                    ]

instance Arbitrary WalletError where
    arbitrary = WalletError <$> choose (1,999) <*> pure "The given AccountId is not correct."

--
-- Domain-specific types, mostly placeholders.
--

type BackupPhrase = Text
type Passphrase   = Text

data WalletAssurance = AssuranceNormal
                     | AssuranceStrict
                     deriving (Eq, Show, Enum, Bounded)

instance Arbitrary WalletAssurance where
    arbitrary = elements [minBound .. maxBound]

deriveJSON Serokell.defaultOptions ''WalletAssurance

-- | A Wallet ID.
newtype WalletId = WalletId Text deriving (Show, Eq, Generic)

deriveJSON Serokell.defaultOptions ''WalletId

instance Arbitrary WalletId where
  arbitrary =
      let wid = "J7rQqaLLHBFPrgJXwpktaMB1B1kQBXAyc2uRSfRPzNVGiv6TdxBzkPNBUWysZZZdhFG9gRy3sQFfX5wfpLbi4XTFGFxTg"
          in WalletId . fromString <$> elements [wid]

instance FromHttpApiData WalletId where
    parseQueryParam = Right . WalletId

instance ToHttpApiData WalletId where
    toQueryParam (WalletId wid) = wid

type Coins = Int

-- | A type modelling the request for a new wallet.
data NewWallet = NewWallet {
      newwalBackupPhrase :: BackupPhrase
    , newwalPassphrase   :: Maybe Passphrase
    } deriving (Eq, Show, Generic)

deriveJSON Serokell.defaultOptions  ''NewWallet

instance Arbitrary NewWallet where
  arbitrary = NewWallet <$> pure "MyBackupPhraseHashed"
                        <*> pure (Just "My passphrase")

-- | A type modelling the update of an existing wallet.
data WalletUpdate = WalletUpdate {
      uwalUnit      :: !Int
    , uwalAssurance :: WalletAssurance
    , uwalName      :: Text
    } deriving (Eq, Show, Generic)

deriveJSON Serokell.defaultOptions  ''WalletUpdate

instance Arbitrary WalletUpdate where
  arbitrary = WalletUpdate <$> fmap getPositive arbitrary
                           <*> arbitrary
                           <*> fmap fromString arbitrary

-- | A Wallet.
data Wallet = Wallet {
      walId        :: WalletId
    , walUnit      :: !Int
    , walAssurance :: WalletAssurance
    -- | The name for this wallet.
    , walName      :: Text
    } deriving (Eq, Show, Generic)

deriveJSON Serokell.defaultOptions  ''Wallet

instance Arbitrary Wallet where
  arbitrary = Wallet <$> arbitrary
                     <*> fmap getPositive arbitrary
                     <*> arbitrary
                     <*> pure "My wallet"

-- Placeholder.
newtype Address = Address
  { addrId :: Text -- ^ A base58 Public Key.
  } deriving (Show, Eq, Generic)

deriveJSON Serokell.defaultOptions ''Address

instance Arbitrary Address where
  arbitrary = Address . fromString <$> elements ["DEADBeef", "123456"]

type AccountId = Text

-- | A wallet 'Account'.
data Account = Account
  { accId        :: !AccountId
  , accAddresses :: [Address]
  , accAmount    :: !Coins
  -- | The Account name.
  , accName      :: !Text
  -- | The parent Wallet Id.
  , accWalletId  :: WalletId
  } deriving (Show, Eq, Generic)

deriveJSON Serokell.defaultOptions ''Account

instance Arbitrary Account where
  arbitrary = Account . fromString <$> elements ["DEADBeef", "123456"]
                                   <*> listOf1 arbitrary
                                   <*> fmap getPositive arbitrary
                                   <*> pure "My account"
                                   <*> arbitrary

data AccountUpdate = AccountUpdate
  { uaccName      :: !Text
  } deriving (Show, Eq, Generic)

deriveJSON Serokell.defaultOptions ''AccountUpdate

instance Arbitrary AccountUpdate where
  arbitrary = AccountUpdate . fromString <$> pure "myAccount"

-- | A type incapsulating a password update request.
data PasswordUpdate = PasswordUpdate
  { -- | The old password.
    pwdOld :: !Text
    -- | The new password.
  , pwdNew :: !Text
  } deriving (Show, Eq, Generic)

deriveJSON Serokell.defaultOptions ''PasswordUpdate

instance Arbitrary PasswordUpdate where
  arbitrary = PasswordUpdate <$> fmap fromString arbitrary
                             <*> fmap fromString arbitrary

-- | `EstimatedFees` represents the fees which would be generated
-- for a payment in case the latter would actually be performed.
data EstimatedFees = EstimatedFees
  { -- | The estimated fees, as coins.
    feeEstimatedAmount :: !Coins
  } deriving (Show, Eq, Generic)

deriveJSON Serokell.defaultOptions ''EstimatedFees

instance Arbitrary EstimatedFees where
  arbitrary = EstimatedFees <$> fmap getPositive arbitrary

-- | Stub type for a `Payment`.
data Payment = Payment
  { -- | The source Account.
    pmtSourceAccount      :: !Account
    -- | The destination Address.
  , pmtDestinationAddress :: !Address
    -- | The amount for this payment.
  , pmtAmount             :: !Coins
  } deriving (Show, Eq, Generic)

deriveJSON Serokell.defaultOptions ''Payment

instance Arbitrary Payment where
  arbitrary = Payment <$> arbitrary
                      <*> arbitrary
                      <*> fmap getPositive arbitrary

type TxId = Text

-- | A Wallet Transaction.
data Transaction = Transaction
  { -- | The Tx Id.
    txId            :: TxId
    -- | The number of confirmations.
  , txConfirmations :: !Int
    -- | The coins moved as part of this transaction.
  , txAmount        :: !Coins
  } deriving (Show, Eq, Generic)

deriveJSON Serokell.defaultOptions ''Transaction

instance Arbitrary Transaction where
  arbitrary = Transaction <$> fmap fromString arbitrary
                          <*> fmap getPositive arbitrary
                          <*> fmap getPositive arbitrary

-- | A type representing an upcoming wallet update.
data WalletSoftwareUpdate = WalletSoftwareUpdate
  { updSoftwareVersion   :: !Text
  , updBlockchainVersion :: !Text
  , updScriptVersion     :: !Int
  -- Other types omitted for now.
  } deriving (Show, Eq, Generic)

deriveJSON Serokell.defaultOptions ''WalletSoftwareUpdate

instance Arbitrary WalletSoftwareUpdate where
  arbitrary = WalletSoftwareUpdate <$> fmap fromString arbitrary
                                   <*> fmap fromString arbitrary
                                   <*> fmap getPositive arbitrary

--
-- POST/PUT requests isomorphisms
--

type family Update (original :: *) :: * where
  Update Wallet  = WalletUpdate
  Update Account = AccountUpdate

type family New (original :: *) :: * where
  New Wallet  = NewWallet
  New Account = AccountUpdate -- POST == PUT
