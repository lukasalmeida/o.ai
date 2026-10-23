-- ==========================================================
--  TX ROLEPLAY | ESTRUTURA BASE DO BANCO DE DADOS
--  Tabelas essenciais para servidor RP simples
--  Execute: mysql -u root -p1997 fivem < core_tables.sql
-- ==========================================================

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- ------------------------------------------------------------
--  USUÁRIOS / PERSONAGENS
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `users` (
    `id`              INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `identifier`      VARCHAR(64)  NOT NULL COMMENT 'license:xxxx / steam:xxxx / discord:xxxx',
    `license`         VARCHAR(64)  NULL COMMENT 'license do FiveM',
    `steam`           VARCHAR(64)  NULL COMMENT 'steam hex',
    `discord`         VARCHAR(64)  NULL COMMENT 'discord id',
    `ip`              VARCHAR(45)  NULL COMMENT 'último IP',
    `name`            VARCHAR(64)  NOT NULL DEFAULT 'Cidadão' COMMENT 'nome RP (ex: João Silva)',
    `firstname`       VARCHAR(32)  NOT NULL DEFAULT 'João',
    `lastname`        VARCHAR(32)  NOT NULL DEFAULT 'Silva',
    `dateofbirth`     DATE         NULL COMMENT 'data de nascimento RP',
    `sex`             VARCHAR(1)   NOT NULL DEFAULT 'M' COMMENT 'M ou F',
    `height`          FLOAT        NOT NULL DEFAULT 1.75 COMMENT 'altura em metros',
    `skin`            LONGTEXT     NULL COMMENT 'JSON da aparência (ped model + components)',
    `is_dead`         TINYINT(1)   NOT NULL DEFAULT 0,
    `last_position`   JSON         NULL COMMENT '{x,y,z,heading}',
    `health`          INT          NOT NULL DEFAULT 200,
    `armor`           INT          NOT NULL DEFAULT 0,
    `hunger`          INT          NOT NULL DEFAULT 100,
    `thirst`          INT          NOT NULL DEFAULT 100,
    `stress`          INT          NOT NULL DEFAULT 0,
    `playtime`        INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'tempo total em segundos',
    `created_at`      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at`      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    `deleted_at`      TIMESTAMP    NULL DEFAULT NULL COMMENT 'soft delete',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uniq_identifier` (`identifier`),
    KEY `idx_license` (`license`),
    KEY `idx_steam` (`steam`),
    KEY `idx_discord` (`discord`),
    KEY `idx_name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
--  CONTAS BANCÁRIAS / DINHEIRO
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `user_accounts` (
    `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `user_id`     INT UNSIGNED NOT NULL,
    `account`     VARCHAR(32)  NOT NULL COMMENT 'bank, cash, dirty_money',
    `money`       BIGINT       NOT NULL DEFAULT 0 COMMENT 'em centavos para precisão',
    `updated_at`  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uniq_user_account` (`user_id`, `account`),
    KEY `idx_user` (`user_id`),
    CONSTRAINT `fk_accounts_user` FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
--  POSIÇÕES / SPAWN
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `user_positions` (
    `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `user_id`     INT UNSIGNED NOT NULL,
    `x`           DOUBLE       NOT NULL,
    `y`           DOUBLE       NOT NULL,
    `z`           DOUBLE       NOT NULL,
    `heading`     FLOAT        NOT NULL DEFAULT 0,
    `interior`    INT          NOT NULL DEFAULT 0,
    `dimension`   INT          NOT NULL DEFAULT 0,
    `is_spawn`    TINYINT(1)   NOT NULL DEFAULT 0 COMMENT 'última posição conhecida para spawn',
    `updated_at`  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_user` (`user_id`),
    KEY `idx_spawn` (`user_id`, `is_spawn`),
    CONSTRAINT `fk_positions_user` FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
--  LICENÇAS
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `user_licenses` (
    `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `user_id`     INT UNSIGNED NOT NULL,
    `type`        VARCHAR(32)  NOT NULL COMMENT 'drive, weapon, pilot, boat, etc',
    `status`      TINYINT(1)   NOT NULL DEFAULT 1 COMMENT '1 = válida, 0 = revogada',
    `issued_at`   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `expires_at`  TIMESTAMP    NULL DEFAULT NULL,
    `revoked_at`  TIMESTAMP    NULL DEFAULT NULL,
    `revoked_by`  INT UNSIGNED NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uniq_user_license` (`user_id`, `type`),
    KEY `idx_user` (`user_id`),
    CONSTRAINT `fk_licenses_user` FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
--  EMPREGOS / CARGOS
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `user_jobs` (
    `id`              INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `user_id`         INT UNSIGNED NOT NULL,
    `job_name`        VARCHAR(32)  NOT NULL DEFAULT 'unemployed',
    `job_label`       VARCHAR(64)  NOT NULL DEFAULT 'Desempregado',
    `grade`           INT          NOT NULL DEFAULT 0,
    `grade_label`     VARCHAR(64)  NOT NULL DEFAULT 'Civil',
    `salary`          INT          NOT NULL DEFAULT 0,
    `is_whitelisted`  TINYINT(1)   NOT NULL DEFAULT 0,
    `duty`            TINYINT(1)   NOT NULL DEFAULT 1 COMMENT 'em serviço',
    `updated_at`      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uniq_user_job` (`user_id`),
    KEY `idx_user` (`user_id`),
    KEY `idx_job` (`job_name`),
    CONSTRAINT `fk_jobs_user` FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
--  VEÍCULOS PROPRIEDADE DO JOGADOR
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `user_vehicles` (
    `id`              INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `user_id`         INT UNSIGNED NOT NULL,
    `model`           VARCHAR(64)  NOT NULL COMMENT 'model name (ex: sultan2)',
    `plate`           VARCHAR(12)  NOT NULL COMMENT 'placa formatada',
    `plate_raw`       VARCHAR(12)  NOT NULL COMMENT 'placa sem espaços',
    `stored`          TINYINT(1)   NOT NULL DEFAULT 1 COMMENT '1 = na garagem, 0 = fora',
    `garage`          VARCHAR(32)  NOT NULL DEFAULT 'pillbox',
    `fuel`            FLOAT        NOT NULL DEFAULT 100,
    `engine_health`   FLOAT        NOT NULL DEFAULT 1000,
    `body_health`     FLOAT        NOT NULL DEFAULT 1000,
    `mods`            LONGTEXT     NULL COMMENT 'JSON dos mods (tuning)',
    `color_primary`   INT          NULL,
    `color_secondary` INT          NULL,
    `color_pearlescent` INT        NULL,
    `color_wheel`     INT          NULL,
    `mileage`         FLOAT        NOT NULL DEFAULT 0 COMMENT 'km rodados',
    `created_at`      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at`      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uniq_plate` (`plate_raw`),
    KEY `idx_user` (`user_id`),
    KEY `idx_stored` (`user_id`, `stored`),
    CONSTRAINT `fk_vehicles_user` FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
--  CHAVES DE VEÍCULOS (compartilhamento)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `vehicle_keys` (
    `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `vehicle_id`  INT UNSIGNED NOT NULL,
    `user_id`     INT UNSIGNED NOT NULL,
    `created_at`  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uniq_vehicle_user` (`vehicle_id`, `user_id`),
    KEY `idx_user` (`user_id`),
    CONSTRAINT `fk_keys_vehicle` FOREIGN KEY (`vehicle_id`) REFERENCES `user_vehicles`(`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_keys_user` FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
--  ITENS DO JOGADOR (já existe player_items, mantido para compat)
-- ------------------------------------------------------------
-- A tabela player_items já foi criada pelo inventory.sql
-- Ela serve como inventário principal (mochila + hotbar + extras)

-- ------------------------------------------------------------
--  REGISTRO DE TRANSAÇÕES (auditoria de dinheiro)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `transactions` (
    `id`              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `from_user_id`    INT UNSIGNED    NULL,
    `to_user_id`      INT UNSIGNED    NULL,
    `amount`          BIGINT          NOT NULL COMMENT 'em centavos',
    `type`            VARCHAR(32)     NOT NULL COMMENT 'transfer, salary, fine, shop, sell, etc',
    `description`     VARCHAR(255)    NULL,
    `metadata`        JSON            NULL,
    `created_at`      TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_from` (`from_user_id`),
    KEY `idx_to` (`to_user_id`),
    KEY `idx_type` (`type`),
    KEY `idx_date` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
--  REGISTRO DE ADMIN / LOGS
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `admin_logs` (
    `id`          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `admin_id`    INT UNSIGNED    NOT NULL,
    `target_id`   INT UNSIGNED    NULL,
    `action`      VARCHAR(64)     NOT NULL COMMENT 'kick, ban, revive, giveitem, setjob, etc',
    `reason`      VARCHAR(255)    NULL,
    `metadata`    JSON            NULL,
    `created_at`  TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_admin` (`admin_id`),
    KEY `idx_target` (`target_id`),
    KEY `idx_action` (`action`),
    KEY `idx_date` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
--  BANS
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `bans` (
    `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `identifier`  VARCHAR(64)  NOT NULL,
    `license`     VARCHAR(64)  NULL,
    `steam`       VARCHAR(64)  NULL,
    `discord`     VARCHAR(64)  NULL,
    `ip`          VARCHAR(45)  NULL,
    `reason`      VARCHAR(255) NOT NULL,
    `banned_by`   INT UNSIGNED NULL,
    `expires_at`  TIMESTAMP    NULL DEFAULT NULL COMMENT 'NULL = permanente',
    `created_at`  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `unbanned_at` TIMESTAMP    NULL DEFAULT NULL,
    `unbanned_by` INT UNSIGNED NULL,
    PRIMARY KEY (`id`),
    KEY `idx_identifier` (`identifier`),
    KEY `idx_license` (`license`),
    KEY `idx_steam` (`steam`),
    KEY `idx_discord` (`discord`),
    KEY `idx_ip` (`ip`),
    KEY `idx_expires` (`expires_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
--  WHITELIST
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `whitelist` (
    `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `identifier`  VARCHAR(64)  NOT NULL,
    `license`     VARCHAR(64)  NULL,
    `steam`       VARCHAR(64)  NULL,
    `discord`     VARCHAR(64)  NULL,
    `approved_by` INT UNSIGNED NULL,
    `created_at`  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uniq_identifier` (`identifier`),
    KEY `idx_license` (`license`),
    KEY `idx_steam` (`steam`),
    KEY `idx_discord` (`discord`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
--  DADOS INICIAIS - Contas padrão para novos usuários
-- ------------------------------------------------------------
-- Trigger para criar contas automaticamente quando usuário é criado
DELIMITER $$

CREATE TRIGGER `users_after_insert` AFTER INSERT ON `users`
FOR EACH ROW
BEGIN
    INSERT IGNORE INTO `user_accounts` (`user_id`, `account`, `money`) VALUES
        (NEW.id, 'cash', 500000),      -- $5.000,00 em centavos
        (NEW.id, 'bank', 1000000),     -- $10.000,00 em centavos
        (NEW.id, 'dirty_money', 0);
    
    INSERT IGNORE INTO `user_jobs` (`user_id`, `job_name`, `job_label`, `grade`, `grade_label`, `salary`)
        VALUES (NEW.id, 'unemployed', 'Desempregado', 0, 'Civil', 0);
    
    INSERT IGNORE INTO `user_licenses` (`user_id`, `type`, `status`) VALUES
        (NEW.id, 'drive', 0),
        (NEW.id, 'weapon', 0);
END$$

DELIMITER ;

-- ------------------------------------------------------------
--  VIEWS ÚTEIS
-- ------------------------------------------------------------

-- View: Usuário completo com contas, job, posição
CREATE OR REPLACE VIEW `v_user_full` AS
SELECT 
    u.*,
    ua_cash.money as cash,
    ua_bank.money as bank,
    ua_dirty.money as dirty_money,
    uj.job_name, uj.job_label, uj.grade, uj.grade_label, uj.salary, uj.duty,
    up.x, up.y, up.z, up.heading
FROM `users` u
LEFT JOIN `user_accounts` ua_cash ON ua_cash.user_id = u.id AND ua_cash.account = 'cash'
LEFT JOIN `user_accounts` ua_bank ON ua_bank.user_id = u.id AND ua_bank.account = 'bank'
LEFT JOIN `user_accounts` ua_dirty ON ua_dirty.user_id = u.id AND ua_dirty.account = 'dirty_money'
LEFT JOIN `user_jobs` uj ON uj.user_id = u.id
LEFT JOIN `user_positions` up ON up.user_id = u.id AND up.is_spawn = 1
WHERE u.deleted_at IS NULL;

-- View: Veículos do jogador
CREATE OR REPLACE VIEW `v_user_vehicles` AS
SELECT 
    uv.*,
    u.name as owner_name,
    u.identifier as owner_identifier
FROM `user_vehicles` uv
JOIN `users` u ON u.id = uv.user_id
WHERE u.deleted_at IS NULL;

SET FOREIGN_KEY_CHECKS = 1;

-- ------------------------------------------------------------
--  DADOS DE EXEMPLO (opcional - remova em produção)
-- ------------------------------------------------------------
-- INSERT INTO `users` (`identifier`, `license`, `firstname`, `lastname`, `name`, `dateofbirth`, `sex`, `height`)
-- VALUES ('license:test123', 'license:test123', 'João', 'Silva', 'João Silva', '1990-01-15', 'M', 1.80);