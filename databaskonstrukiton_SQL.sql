drop database a21rammo;
create database a21rammo;
use a21rammo;
 
 /** Barn-pnr består av fyrsiffrigt löpnummer följt av en 6-siffrig regionskod och en fyrsiffrig datum kod**/
create table kid(
    PNR char(14),
    name varchar(32) unique NOT NULL,
    birthday year,
    disobedience INTEGER NOT NULL,
    deliveryNr INTEGER NOT NULL,
    type varchar(32),
    primary key(pnr)
)engine=InnoDB;
    
create table related(
	relatedName varchar(32) NOT NULL,
    PNR char(14),
    primary key(relatedName, PNR),
    foreign key(PNR) references kid(PNR)
)engine=InnoDB;
    
    
create table recording(
	PNR char(14),
    timestamp timestamp NOT NULL,
    description varchar(255),
    quality INTEGER,
    filename varchar(32),
    primary key(timestamp, PNR),
    foreign key(PNR) references kid(PNR)
)engine=InnoDB;

CREATE TABLE toy(
	toyId INTEGER,
    toyName varchar(32),
    toySizeCM varchar(14),
    magicPercentage INTEGER,
    toyPriceSEK INTEGER,
    toyWeightKG FLOAT,
    primary key(toyId)
)engine=InnoDB;

create table wishlist(
    year year,
    PNR char(14),
    toyId INTEGER,
    description varchar(244),
    conceded varchar(30),
    delivered varchar(5),
    primary key(year, PNR, toyId),
    foreign key(PNR) references kid(PNR),
    foreign key(toyId) references toy(toyId)
)engine=InnoDB;

CREATE TABLE wishlistrow(
	wishlistrow INTEGER,
    wishlistYear year,
    toyId integer UNIQUE,
    comment varchar(255),
    primary key(wishlistrow, wishlistYear, toyId),
	foreign key(wishlistYear) references wishlist(year),
	foreign key(toyId) references toy(toyId)
)engine=InnoDB;
    
    

create table chores(
    chores varchar(255) NOT NULL,
    PNR char(14),
    primary key(chores, PNR),
	foreign key(PNR) references kid(PNR)
)engine=InnoDB;

----- INSERT VALUES ------
INSERT INTO kid VALUES ("28897602910310", "Gustav Persson", 2010, 1, 10, "good kid");
INSERT INTO kid VALUES ("11486490520309" , "Nils Lundgren", 2009, 1, 10, "good kid");
INSERT INTO kid VALUES ("71705265441199" , "Raman Mohammed", 1999, 1, 10, "good kid");
INSERT INTO kid VALUES ("34909941759502" , "Legolas Lego", 2002, 100, 10, "less of good kid");

INSERT INTO chores VALUES("Helping elderly people", 11486490520309);
INSERT INTO chores VALUES("Cleaning room", 11486490520309);

INSERT INTO toy VALUES(1, "A big firetruck", "5cm", 5, "100", "54.3");

INSERT INTO toy VALUES(2, "A big firetruck", "5cm", 5, "200", "54.3");
INSERT INTO wishlist VALUES(2020,"11486490520309", 1, "A big toy", "yes", "true");



----- INDEXERING ----- 
EXPLAIN SELECT name from kid where name="Raman Mohammed";
CREATE INDEX kidName on kid(name);

show index from kid;

----- Horizontal Denormalization ----
create table recordtext(
	PNR char(14),
    timestamp timestamp NOT NULL,
    text varchar(1028),
    primary key(timestamp),
    foreign key(PNR) references kid(PNR)
)engine=InnoDB;


----- Vertical Denormalization -----
create table deliveredWishlist(
    year year,
    PNR char(14),
    description varchar(244),
    conceded varchar(30),
    delivered varchar(5),
    primary key(year, PNR),
    foreign key(PNR) references kid(PNR)
)engine=InnoDB;


----- Views -----
/** Views are virtual tables, tables that appear to the database or user but in reality do not exist as tables,
but rather as queries on other views or tables **/ 
/** First time of view is simplify which is splitting partial results into seperate views**/
CREATE VIEW kidsWishlist AS
SELECT kid.name, wishlist.*
FROM kid, wishlist
WHERE kid.PNR=wishlist.PNR;

/** Second one is to specialize the database towards a specific kind of application (can be good for statistics) **/
CREATE VIEW AvgKidYear AS
SELECT AVG(birthday)
FROM kid
GROUP BY YEAR(birthday);

CREATE TABLE kidsInfoYear(
	PNR VARCHAR(14),
    maxBirthday YEAR,
    avgBirthday YEAR,
    PRIMARY KEY (PNR)
)ENGINE=INNODB;

/** Third one is to control privileges of parts of a table by giving users privileges to views and not to base tables **/
CREATE VIEW limit_kids AS
SELECT name, birthday, disobedience
FROM kid;

/** forth is creating views for check constraint. we need to check if all the kids are still kids (below 18) **/
CREATE VIEW checkAge AS
SELECT *
FROM kid
WHERE ((birthday>"2004"))
WITH CHECK OPTION;

----- CREATE USERS -----
/*DROP USER 'raman'; */
CREATE USER 'raman'@'%' IDENTIFIED BY 'user_password';
GRANT ALL PRIVILEGES ON *.* TO 'raman'@'%'; 

----- Stored Procedure -----
DELIMITER // 
CREATE PROCEDURE SetKidLevel(InPNR varchar(14), InLevel integer)
BEGIN
	update kid SET level=InLevel WHERE PNR=InPNR;
END//
DELIMITER ;

/** CREATE LOG TRIGGER  **/

CREATE TABLE kidLog(
	operation varchar(15),
    username varchar(32),
    kidPNR varchar(14),
    optime datetime,
    PRIMARY KEY(optime)
)ENGINE=INNODB;


DELIMITER //
CREATE PROCEDURE GetKidsLog(logPNR VARCHAR(14))
BEGIN
	INSERT INTO kidLog(operation,username,kidPNR, optime) VALUES ("SEL", USER(),logPNR, NOW());
    
SELECT name
FROM kid
WHERE logPNR=PNR;
END//

DELIMITER ;


/** Signal procedure which aborts execution of procedure. **/

DELIMITER //
CREATE PROCEDURE AbortChangingKidType(InType VARCHAR(30))
BEGIN
DECLARE `kids_cant_be_bad` CONDITION FOR SQLSTATE '45000';
	IF (InType="bad") THEN
		SIGNAL kids_cant_be_bad SET message_text="Kids can only be good or less good";
	END IF;
END //

DELIMITER ;

/** TRIGGER TO REPLACE THE VIEW 
	SQLSTATE "02000" No row was found for fetch update or delete
    SQLSTATE "23000" Integrity constraint violation
    STILL NOT WORKING PROPERLY
**/
DELIMITER //

CREATE PROCEDURE SetYearKid(InPNR varchar(14), InBirthday year)
BEGIN
	DECLARE done INT DEFAULT 0;
    DECLARE PNR varchar(14);
    DECLARE PMAXBIRTHDAY YEAR;
    DECLARE PAVGBIRTHDAY YEAR;
    DECLARE cur CURSOR FOR SELECT max(birthday), AVG(birthday), PNR FROM kid GROUP BY birthday HAVING birthday IS NOT NULL;
    DECLARE CONTINUE HANDLER FOR SQLSTATE'02000' SET DONE=1;
	DECLARE CONTINUE HANDLER FOR SQLSTATE'23000' SET DONE=1;
    
    UPDATE kid SET birthday=InBirthday WHERE PNR=InPNR;
    
    DELETE FROM kidsInfoYear;
    
    OPEN cur;
    lbl: LOOP
		IF done=1 THEN LEAVE lbl;
        END IF;
        
        IF NOT done=1 THEN
			FETCH cur INTO PNR, PMAXBIRTHDAY, PAVGBIRTHDAY;
            INSERT INTO kidsInfoYear VALUES(PNR, PMAXBIRTHDAY, PAVGBIRTHDAY);
		END IF;
	END LOOP;
    CLOSE CUR;
    
END//
        
DELIMITER ;


/** TRIGGERS **/

DELIMITER //
CREATE TRIGGER LOGGTRIGGER AFTER INSERT ON kid
FOR EACH ROW BEGIN
	INSERT INTO kidLog(operation,username,kidPNR, optime) VALUES ("INS", USER(),NEW.PNR,NOW());
END//

DELIMITER ;


DELIMITER //
CREATE TRIGGER INSERTCHECK BEFORE INSERT ON kid
FOR EACH ROW BEGIN
IF(NEW.birthday<2004) THEN
 SIGNAL SQLSTATE '45000' set message_text ="The birthday cant be older than
18."
END IF;
END;

DELIMITER ;

INSERT INTO kid VALUES ("99990000222233", "David Davidson", 2000, 1, 10, "good kid");

SELECT * FROM kid;
SELECT * FROM kidLog;
SELECT * FROM kidsInfoYear;

