module Main where

import Prelude (($), (<$>), (<<<), bind, pure)
import Control.Bind ((=<<))
import Control.Monad.Eff (Eff)
import Control.SocketIO.Client (SocketIO, connect, on)
import DOM (DOM)
import Data.Lens (set)
import Data.Maybe (Maybe(..))
import Explorer.Api.Socket (toEvent)
import Explorer.Api.Socket (blocksUpdatedEventHandler, callYouEventHandler, callYouStringEventHandler, callYouCTxIdEventHandler, mkSocketHost, connectEvent, closeEvent, connectHandler, closeHandler, txsUpdatedHandler) as Ex
import Explorer.Lenses.State (connection, socket)
import Explorer.Routes (match)
import Explorer.Types.Actions (Action(..)) as Ex
import Explorer.Types.State (State) as Ex
import Explorer.Update (update) as Ex
import Explorer.Util.Config (hostname, isProduction, secureProtocol)
import Explorer.View.Layout (view)
import Network.HTTP.Affjax (AJAX)
import Pos.Explorer.Socket.Methods (ServerEvent(..))
import Pux (App, Config, CoreEffects, Update, renderToDOM, start)
import Pux.Devtool (Action, start) as Pux.Devtool
import Pux.Router (sampleUrl)
import Signal (Signal, (~>))
import Signal.Channel (channel, subscribe)

type AppEffects = (dom :: DOM, ajax :: AJAX, socket :: SocketIO)

config :: Ex.State -> Eff (CoreEffects AppEffects) (Config Ex.State Ex.Action AppEffects)
config state = do
  -- routing
  urlSignal <- sampleUrl
  let routeSignal = urlSignal ~> Ex.UpdateView <<< match
  -- socket
  actionChannel <- channel $ Ex.SocketConnected false
  let socketSignal = subscribe actionChannel :: Signal Ex.Action
  socketHost <- Ex.mkSocketHost (secureProtocol isProduction) <$> hostname
  socket' <- connect socketHost
  on socket' Ex.connectEvent $ Ex.connectHandler actionChannel
  on socket' Ex.closeEvent $ Ex.closeHandler actionChannel
  on socket' (toEvent TxsUpdated) $ Ex.txsUpdatedHandler actionChannel
  on socket' (toEvent BlocksUpdated) $ Ex.blocksUpdatedEventHandler actionChannel
  on socket' (toEvent CallYou) $ Ex.callYouEventHandler actionChannel
  on socket' (toEvent CallYouString) $ Ex.callYouStringEventHandler actionChannel
  on socket' (toEvent CallYouTxId) $ Ex.callYouCTxIdEventHandler actionChannel

  pure
    { initialState: set (socket <<< connection) (Just socket') state
    , update: Ex.update :: Update Ex.State Ex.Action AppEffects
    , view: view
    , inputs: [socketSignal, routeSignal]
    }

appSelector :: String
appSelector = "#explorer"

main :: Ex.State -> Eff (CoreEffects AppEffects) (App Ex.State Ex.Action)
main state = do
  app <- start =<< config state
  renderToDOM appSelector app.html
  pure app

debug :: Ex.State -> Eff (CoreEffects AppEffects) (App Ex.State (Pux.Devtool.Action Ex.Action))
debug state = do
  appConfig <- config state
  app <- Pux.Devtool.start appConfig {opened: false}
  renderToDOM appSelector app.html
  pure app
