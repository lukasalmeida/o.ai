-- ==========================================================
--  TX_INVENTORY | ESTRUTURA DO BANCO DE DADOS (MySQL / MariaDB)
--  Importe este arquivo no phpMyAdmin, HeidiSQL ou pelo console:
--      mysql -u root -p < inventory.sql
--
--  O recurso também cria as tabelas automaticamente ao iniciar
--  (se o usuário do banco tiver permissão CREATE).
-- ==========================================================

-- ------------------------------------------------------------
--  Tabela de itens do jogador (mochila + hotbar)
--  slot: 1..30 = mochila | 31..35 = hotbar | 36+ = extras de mochila
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `player_items` (
    `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `identifier` VARCHAR(64)  NOT NULL COMMENT 'license:xxxx / steam:xxxx',
    `item_name`  VARCHAR(64)  NOT NULL,
    `slot`       TINYINT      NOT NULL DEFAULT 0 COMMENT '0 = fora de slot',
    `amount`     INT UNSIGNED NOT NULL DEFAULT 1,
    `metadata`   TEXT         NULL COMMENT 'JSON: serial, ammo, props...',
    `equipped`   TINYINT(1)   NOT NULL DEFAULT 0 COMMENT 'arma equipada',
    `created_at` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_ident` (`identifier`),
    KEY `idx_ident_slot` (`identifier`, `slot`),
    KEY `idx_item` (`item_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
--  Tabela de itens largados no chão
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `ground_items` (
    `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `instance`   VARCHAR(64)  NOT NULL COMMENT 'id unico do item no chao',
    `item_name`  VARCHAR(64)  NOT NULL,
    `amount`     INT UNSIGNED NOT NULL DEFAULT 1,
    `metadata`   TEXT         NULL,
    `x`          DOUBLE       NOT NULL DEFAULT 0,
    `y`          DOUBLE       NOT NULL DEFAULT 0,
    `z`          DOUBLE       NOT NULL DEFAULT 0,
    `created_at` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `expires_at` TIMESTAMP    NULL DEFAULT NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uniq_instance` (`instance`),
    KEY `idx_pos` (`x`, `y`, `z`),
    KEY `idx_expires` (`expires_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
--  (Opcional) Tabela de exemplo para testar o sistema
-- ------------------------------------------------------------
-- INSERT INTO `player_items` (`identifier`, `item_name`, `slot`, `amount`, `metadata`)
-- VALUES ('license:EXEMPLO', 'water', 1, 5, NULL),
--        ('license:EXEMPLO', 'bread', 2, 3, NULL),
--        ('license:EXEMPLO', 'pistol', 31, 1, '{"serial":"12345","ammo":50}');
