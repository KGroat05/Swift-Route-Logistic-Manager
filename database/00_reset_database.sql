-- =====================================================================
-- Swift Route Logistics Manager
-- 21CSC205P Database Management Systems - Mini Project
-- Database Reset Script: 00_reset_database.sql
-- Engine: MySQL 8.4 LTS
-- =====================================================================

-- !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
-- WARNING: DESTRUCTIVE OPERATION
-- THIS SCRIPT COMPLETELY DROPS AND RE-CREATES THE 'swiftroute' DATABASE.
-- ALL EXISTING TABLES, VIEWS, TRIGGERS, PROCEDURES, AND DATA WILL BE 
-- PERMANENTLY DELETED.
-- THIS SCRIPT IS STRICTLY INTENDED FOR LOCAL DEVELOPMENT ENVIRONMENTS.
-- DO NOT RUN THIS SCRIPT IN A PRODUCTION ENVIRONMENT!
-- !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

SELECT '*** WARNING: INITIATING COMPLETE DATABASE RESET FOR SWIFT ROUTE LOGISTICS MANAGER ***' AS notice;

-- Temporarily disable foreign key checks to allow clean teardown
SET @OLD_FOREIGN_KEY_CHECKS = @@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS = 0;
SET @OLD_SQL_MODE = @@SQL_MODE, SQL_MODE = 'STRICT_TRANS_TABLES,NO_ENGINE_SUBSTITUTION';

-- Drop database if it exists
DROP DATABASE IF EXISTS swiftroute;

-- Re-create database with standard utf8mb4 encoding
CREATE DATABASE swiftroute
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE swiftroute;

-- Restore settings
SET FOREIGN_KEY_CHECKS = @OLD_FOREIGN_KEY_CHECKS;
SET SQL_MODE = @OLD_SQL_MODE;

SELECT 'Database [swiftroute] has been freshly re-created and is ready for schema execution.' AS reset_status;
