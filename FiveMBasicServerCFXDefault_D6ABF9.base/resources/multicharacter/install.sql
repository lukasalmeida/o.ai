CREATE TABLE IF NOT EXISTS `characters` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `identifier` VARCHAR(60) NOT NULL,
  `firstname` VARCHAR(50) NOT NULL,
  `lastname` VARCHAR(50) NOT NULL,
  `age` INT(11) NOT NULL,
  `sex` VARCHAR(10) NOT NULL DEFAULT 'male',
  `skin` LONGTEXT DEFAULT NULL,
  `position` LONGTEXT DEFAULT NULL,
  `money` INT(11) NOT NULL DEFAULT 0,
  `bank` INT(11) NOT NULL DEFAULT 0,
  `job` VARCHAR(50) NOT NULL DEFAULT 'unemployed',
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `identifier` (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;