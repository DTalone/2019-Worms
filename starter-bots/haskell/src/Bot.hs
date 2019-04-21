{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE FlexibleInstances #-}

module Bot
  where

import qualified Data.Vector as V
import GHC.Generics (Generic)
import qualified Data.ByteString.Lazy as B
import qualified Data.ByteString.Lazy.UTF8 as UTF8
import Data.Maybe
import System.IO
import Control.Monad
import System.Random
import Data.Aeson (decode,
                   withObject,
                   (.:),
                   encode,
                   FromJSON,
                   ToJSON,
                   parseJSON)

type GameMap = V.Vector (V.Vector Cell)

data State = State { currentRound :: Int,
                     maxRounds :: Int,
                     mapSize :: Int,
                     currentWormId :: Int,
                     consecutiveDoNothingCount :: Int,
                     myPlayer :: Player,
                     opponents :: V.Vector Opponent,
                     map :: GameMap }
             deriving (Show, Generic, Eq)

instance FromJSON State
instance ToJSON   State

data Player = Player { id :: Int,
                       score :: Int,
                       health :: Int,
                       worms :: V.Vector Worm }
              deriving (Show, Generic, Eq)

instance FromJSON Player
instance ToJSON   Player

data Opponent = Opponent { opponentsId :: Int,
                           opponentsScore :: Int,
                           opponentsWorms :: V.Vector OpponentWorm }
              deriving (Show, Generic, Eq)

instance ToJSON   Opponent
instance FromJSON Opponent where
  parseJSON = withObject "Opponent" $ \ v ->
    Opponent <$> v .: "id"
             <*> v .: "score"
             <*> v .: "worms"

data Worm = Worm { wormId :: Int,
                   wormHealth :: Int,
                   position :: Coord,
                   weapon :: Weapon,
                   diggingRange :: Int,
                   movementRange :: Int }
            deriving (Show, Generic, Eq)

instance ToJSON   Worm
instance FromJSON Worm where
  parseJSON = withObject "Worm" $ \ v ->
    Worm <$> v .: "id"
         <*> v .: "health"
         <*> v .: "position"
         <*> v .: "weapon"
         <*> v .: "diggingRange"
         <*> v .: "movementRange"

data OpponentWorm = OpponentWorm { opWormId :: Int,
                                   opWormHealth :: Int,
                                   opPosition :: Coord,
                                   opDiggingRange :: Int,
                                   opMovementRange :: Int }
            deriving (Show, Generic, Eq)

instance ToJSON   OpponentWorm
instance FromJSON OpponentWorm where
  parseJSON = withObject "OpponentWorm" $ \ v ->
    OpponentWorm <$> v .: "id"
                 <*> v .: "health"
                 <*> v .: "position"
                 <*> v .: "diggingRange"
                 <*> v .: "movementRange"

data Coord = Coord { xCoord :: Int, yCoord :: Int }
  deriving (Show, Generic, Eq)

instance ToJSON   Coord
instance FromJSON Coord where
  parseJSON = withObject "Coord" $ \ v ->
    Coord <$> v .: "x"
          <*> v .: "y"

data Weapon = Weapon { damage :: Int,
                       range :: Int }
              deriving (Show, Generic, Eq)

instance FromJSON Weapon
instance ToJSON   Weapon

data Cell = Cell { x :: Int,
                   y :: Int,
                   cellType :: String }
            deriving (Show, Generic, Eq)

instance ToJSON   Cell
instance FromJSON Cell where
  parseJSON = withObject "Cell" $ \ v ->
    Cell <$> v .: "x"
         <*> v .: "y"
         <*> v .: "type"

readGameState :: Int -> IO State
readGameState r = do
  stateString <- B.readFile $ "./rounds/" ++ show r ++ "/state.json"
  let Just state = decode stateString
  return state

data Direction = East
               | NorthEast
               | North
               | NorthWest
               | West
               | SouthWest
               | South
               | SouthEast
  deriving Eq

instance Show Direction where
  show East      = "E"
  show NorthEast = "NE"
  show North     = "N"
  show NorthWest = "NW"
  show West      = "W"
  show SouthWest = "SW"
  show South     = "S"
  show SouthEast = "SE"

data Move = DoNothing
          | Shoot Direction
          | Move Coord
          | Dig Coord

instance Show Move where
  show DoNothing          = "nothing"
  show (Shoot direction)  = "shoot " ++ show direction
  show (Move (Coord x y)) = "move " ++ show x ++ " " ++ show y
  show (Dig (Coord x y))  = "dig " ++ show x ++ " " ++ show y

data CoordWithDirection = CoordWithDirection Coord Direction
  deriving Eq

shootTemplates :: Int -> Player -> GameMap -> Opponent -> [CoordWithDirection]
shootTemplates wormId player map opponent = []

tryToShoot :: Int -> Player -> GameMap -> Opponent -> Maybe Move
tryToShoot wormId player map opponent =
  let templates = shootTemplates wormId player map opponent
      hits      = filter (hitsOponentWorm opponent) templates
  in if hits == []
     then Nothing
     else Just $ coordWithDirectionToShoot $ head hits

coordWithDirectionToShoot :: CoordWithDirection -> Move
coordWithDirectionToShoot (CoordWithDirection _ direction) = Shoot direction

hitsOponentWorm :: Opponent -> CoordWithDirection -> Bool
hitsOponentWorm (Opponent _ _ worms) (CoordWithDirection coord _) =
  any (collides coord) worms

collides :: Coord -> OpponentWorm -> Bool
collides (Coord x y) (OpponentWorm { opPosition = coord' }) =
  x == xCoord coord' &&
  y == yCoord coord'

tryToMoveRandomly :: StdGen -> Int -> Player -> GameMap -> Opponent -> Maybe Move
tryToMoveRandomly g currentWormId (Player { worms = worms' }) map opponent = do
  currentWorm  <- V.find ((== currentWormId) . wormId) worms'
  let wormPosition = position currentWorm
  let (a, g')      = next g
  let x            = (xCoord wormPosition) + (mod a 3) - 1
  let (b, _)       = next g'
  let y            = (yCoord wormPosition) + (mod b 3) - 1
  let mapLength    = V.length map
  if (x < 0 || y < 0 || x >= mapLength || y >= mapLength)
     then Nothing
     else if xCoord wormPosition == x && yCoord wormPosition == y
          then Nothing
          else translateToMoveOrDig ((map V.! y) V.! x)

translateToMoveOrDig :: Cell -> Maybe Move
translateToMoveOrDig (Cell x y "AIR")        = Just $ Move (Coord x y)
translateToMoveOrDig (Cell x y "DIRT")       = Just $ Dig  (Coord x y)
translateToMoveOrDig (Cell x y "DEEP_SPACE") = Nothing

makeMove :: StdGen -> State -> Move
makeMove g (State _ _ _ currentWormId _ myPlayer opponents map) =
  let opponent = (opponents V.!? 0)
  in fromJust $ msum [opponent >>= (tryToShoot          currentWormId myPlayer map),
                      opponent >>= (tryToMoveRandomly g currentWormId myPlayer map),
                      Just DoNothing]

startBot :: StdGen -> Int -> IO ()
startBot g roundNumber = do
  round :: Int <- readLn
  state <- readGameState round
  let (g', g'') = split g
  putStrLn $ "C;" ++ show roundNumber ++ ";" ++ show (makeMove g' state) ++ "\n"
  startBot g'' (roundNumber + 1)
