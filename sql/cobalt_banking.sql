CREATE TABLE IF NOT EXISTS `bank_accounts` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `account_id` VARCHAR(64) NOT NULL,
  `type` VARCHAR(20) NOT NULL DEFAULT 'personal',
  `label` VARCHAR(100) DEFAULT NULL,
  `balance` BIGINT NOT NULL DEFAULT 0,
  `owner_cid` VARCHAR(50) DEFAULT NULL,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `last_updated` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `account_id` (`account_id`),
  KEY `owner_type` (`owner_cid`, `type`),
  KEY `label_type` (`label`, `type`),
  KEY `created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `bank_account_members` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `account_id` VARCHAR(64) NOT NULL,
  `citizenid` VARCHAR(50) NOT NULL,
  `role` VARCHAR(16) NOT NULL DEFAULT 'member',
  `added_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `account_member` (`account_id`, `citizenid`),
  KEY `citizenid` (`citizenid`),
  CONSTRAINT `fk_bank_account_members_account` FOREIGN KEY (`account_id`) REFERENCES `bank_accounts` (`account_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_bank_account_members_player` FOREIGN KEY (`citizenid`) REFERENCES `players` (`citizenid`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `bank_transactions` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `account_id` VARCHAR(64) NOT NULL,
  `counterparty_account_id` VARCHAR(64) DEFAULT NULL,
  `type` VARCHAR(32) NOT NULL,
  `amount` BIGINT NOT NULL,
  `description` VARCHAR(255) DEFAULT NULL,
  `balance_after` BIGINT DEFAULT NULL,
  `reference_id` VARCHAR(100) DEFAULT NULL,
  `receipt` VARCHAR(20) DEFAULT NULL,
  `initiated_by` VARCHAR(50) DEFAULT NULL,
  `initiated_by_archived` VARCHAR(50) DEFAULT NULL,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `account_created` (`account_id`, `created_at`),
  KEY `account_id_id` (`account_id`, `id`),
  KEY `counterparty_created` (`counterparty_account_id`, `created_at`),
  KEY `initiated_by` (`initiated_by`),
  KEY `receipt` (`receipt`),
  KEY `created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `invoices` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `issuer` VARCHAR(32) NOT NULL,
  `citizenid` VARCHAR(50) NOT NULL,
  `payee` VARCHAR(64) NOT NULL,
  `issuer_citizenid` VARCHAR(50) DEFAULT NULL,
  `issuer_name` VARCHAR(120) DEFAULT NULL,
  `summary` VARCHAR(255) NOT NULL DEFAULT '',
  `amount` INT UNSIGNED NOT NULL,
  `status` ENUM('unpaid', 'paid', 'void') NOT NULL DEFAULT 'unpaid',
  `data` LONGTEXT NOT NULL DEFAULT '{}' CHECK (JSON_VALID(`data`)),
  `due_at` DATETIME NOT NULL,
  `declined_at` DATETIME DEFAULT NULL,
  `paid_at` DATETIME DEFAULT NULL,
  `void_reason` VARCHAR(255) DEFAULT NULL,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `citizen_status` (`citizenid`, `status`),
  KEY `issuer_status` (`issuer`, `status`, `due_at`),
  KEY `issuer_citizenid` (`issuer_citizenid`),
  CONSTRAINT `fk_invoices_player` FOREIGN KEY (`citizenid`) REFERENCES `players` (`citizenid`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_invoices_issuer` FOREIGN KEY (`issuer_citizenid`) REFERENCES `players` (`citizenid`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
