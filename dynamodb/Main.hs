--------------------------------------------------
-- Copyright (C) 2017, All rights reserved.
--------------------------------------------------

{-# LANGUAGE FlexibleContexts #-}

-- All of amazonka APIs use Data.Text.Text by default which is nice
{-# LANGUAGE OverloadedStrings #-}

-- Allows record fields to be expanded automatically
{-# LANGUAGE RecordWildCards #-}

module Main (main) where

-- All imports are explicit so we can see exactly where each function comes from
import           AWSViaHaskell
                    ( AWSConfig(..)
                    , AWSConnection
                    , LoggingState(..)
                    , ServiceEndpoint(..)
                    , awsConfig
                    , getAWSConnection
                    , intToText
                    , parseInt
                    , withAWS'
                    )
import           Control.Exception.Lens (handling)
import           Control.Lens ((^.), (.~), (&))
import           Control.Monad (void, when)
import qualified Data.HashMap.Strict as HashMap (fromList, lookup)
import           Data.List.NonEmpty (NonEmpty(..))
import           Data.Text (Text)
import           Network.AWS
                    ( await
                    , send
                    )
import           Network.AWS.DynamoDB
                    ( _ResourceInUseException
                    , _ResourceNotFoundException
                    , KeyType(..)
                    , ScalarAttributeType(..)
                    , attributeDefinition
                    , attributeValue
                    , avN
                    , avS
                    , createTable
                    , ctAttributeDefinitions
                    , deleteTable
                    , describeTable
                    , dynamoDB
                    , getItem
                    , giKey
                    , girsItem
                    , keySchemaElement
                    , piItem
                    , provisionedThroughput
                    , putItem
                    , tableExists
                    , tableNotExists
                    , uiExpressionAttributeValues
                    , uiKey
                    , uiUpdateExpression
                    , updateItem
                    )

data DynamoDBInfo = DynamoDBInfo
    { aws :: AWSConnection
    , tableName :: Text
    }

getDynamoDBInfo :: LoggingState -> ServiceEndpoint -> IO DynamoDBInfo
getDynamoDBInfo loggingState serviceEndpoint = do
    aws <- getAWSConnection $ (awsConfig serviceEndpoint dynamoDB)
                                { acLoggingState = loggingState }
    return $ DynamoDBInfo aws "table"

-- Creates a table in DynamoDB and waits until table is in active state
-- Demonstrates:
-- * Use of runResourceT, runAWST
-- * Use of reconfigure
-- * How to handle exceptions in lenses
-- * Basic use of amazonka-style lenses
-- * How to wait on an asynchronous operation
doCreateTableIfNotExists :: DynamoDBInfo -> IO ()
doCreateTableIfNotExists DynamoDBInfo{..} = withAWS' aws $ do
    newlyCreated <- handling _ResourceInUseException (const (pure False)) $ do
        void $ send $ createTable
                        tableName
                        (keySchemaElement "counter_name" Hash :| [])
                        (provisionedThroughput 5 5)
                        & ctAttributeDefinitions .~ [ attributeDefinition "counter_name" S ]
        return True
    when newlyCreated (void $ await tableExists (describeTable tableName))

-- Deletes a table in DynamoDB if it exists and waits until table no longer exists
doDeleteTableIfExists :: DynamoDBInfo -> IO ()
doDeleteTableIfExists DynamoDBInfo{..} = withAWS' aws $ do
    deleted <- handling _ResourceNotFoundException (const (pure False)) $ do
        void $ send $ deleteTable tableName
        return True
    when deleted (void $ await tableNotExists (describeTable tableName))

-- Puts an item into the DynamoDB table
doPutItem :: DynamoDBInfo -> Int -> IO ()
doPutItem DynamoDBInfo{..} value = withAWS' aws $ do
    void $ send $ putItem tableName
                    & piItem .~ item
    where item = HashMap.fromList
            [ ("counter_name", attributeValue & avS .~ Just "my-counter")
            , ("counter_value", attributeValue & avN .~ Just (intToText value))
            ]

-- Updates an item in the DynamoDB table
doUpdateItem :: DynamoDBInfo -> IO ()
doUpdateItem DynamoDBInfo{..} = withAWS' aws $ do
    void $ send $ updateItem tableName
                    & uiKey .~ key
                    & uiUpdateExpression .~ Just "ADD counter_value :increment"
                    & uiExpressionAttributeValues .~ exprAttrValues
    where
        key = HashMap.fromList
            [ ("counter_name", attributeValue & avS .~ Just "my-counter")
            ]
        exprAttrValues = HashMap.fromList
            [ (":increment", attributeValue & avN .~ Just "1" )
            ]

-- Gets an item from the DynamoDB table
doGetItem :: DynamoDBInfo -> IO (Maybe Int)
doGetItem DynamoDBInfo{..} = withAWS' aws $ do
    result <- send $ getItem tableName
                        & giKey .~ key
    return $ do
        valueAttr <- HashMap.lookup "counter_value" (result ^. girsItem)
        valueNStr <- valueAttr ^. avN
        parseInt valueNStr
    where key = HashMap.fromList
            [ ("counter_name", attributeValue & avS .~ Just "my-counter")
            ]

main :: IO ()
main = do
    --ddbInfo <- getDynamoDBInfo LoggingEnabled (AWS Ohio)
    ddbInfo <- getDynamoDBInfo LoggingDisabled (Local "localhost" 8000)

    putStrLn "DeleteTableIfExists"
    doDeleteTableIfExists ddbInfo

    putStrLn "CreateTableIfNotExists"
    doCreateTableIfNotExists ddbInfo

    putStrLn "PutItem"
    doPutItem ddbInfo 1234

    putStrLn "UpdateItem"
    doUpdateItem ddbInfo

    putStrLn "GetItem"
    counter <- doGetItem ddbInfo
    print counter

    putStrLn "Done"
