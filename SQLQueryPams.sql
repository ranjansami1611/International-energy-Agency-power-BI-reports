USE pams;

-- Procedure to check the Data Types of the selected Tables
	If (object_id('pSelMetaDataByTableName') is not null) Drop Procedure pSelMetaDataByTableName;
go

CREATE PROCEDURE [pSelMetaDataByTableName]
( @TableName nvarchar(200))
AS
 BEGIN 
	SELECT
	  [ColumnFullName] = C.TABLE_SCHEMA  + '.' +  C.TABLE_NAME  + '.' + COLUMN_NAME
	, DataType = Case 
	  When DATA_TYPE in ( 'Money', 'Decimal') 
		Then IsNull(DATA_TYPE,'') 
		+ ' (' +  Cast(NUMERIC_PRECISION as nvarchar(50)) 
		+  ',' +  Cast(NUMERIC_SCALE as nvarchar(50)) 
		+ ' )'
	  When DATA_TYPE in ('bit', 'int', 'tinyint','bigint', 'datetime', 'uniqueidentifier') 
		Then IsNull(DATA_TYPE,'') 
	  Else  IsNull(DATA_TYPE,'') + ' (' +  Cast(IsNull(CHARACTER_MAXIMUM_LENGTH,'') as nvarchar(50)) + ')'
	  End
	, IsNullable = IsNull(IS_NULLABLE,'')
	FROM [INFORMATION_SCHEMA].[COLUMNS] as C
	JOIN [INFORMATION_SCHEMA].[TABLES] as T
	  ON C.TABLE_NAME = T.TABLE_NAME
	WHERE C.TABLE_NAME in (@TableName)
	Order by C.TABLE_SCHEMA, C.TABLE_NAME, C.ORDINAL_POSITION
 END 
 go

EXECUTE pams.dbo.pSelMetaDataByTableName
  @TableName = 'DimCurrency'
;
go

--To remove all the constraints and re run all the codes in order to make changes/add or drop table

DECLARE @sql NVARCHAR(MAX);
SET @sql = N'';

SELECT @sql = @sql + N'
  ALTER TABLE ' + QUOTENAME(s.name) + N'.'
  + QUOTENAME(t.name) + N' DROP CONSTRAINT '
  + QUOTENAME(c.name) + ';'
FROM sys.objects AS c
INNER JOIN sys.tables AS t
ON c.parent_object_id = t.[object_id]
INNER JOIN sys.schemas AS s 
ON t.[schema_id] = s.[schema_id]
WHERE c.[type] IN ('D','C','F','PK','UQ')
ORDER BY c.[type];

PRINT @sql;
EXEC sys.sp_executesql @sql;


-- Creating the date dimension table

If (OBJECT_ID('DimDates') IS NOT NULL) DROP TABLE DimDates;
go

CREATE   
TABLE DimDates	
( CalendarDateKey int Not Null CONSTRAINT [pkDimDates] PRIMARY KEY 
, CalendarDateName nvarchar(50) Not Null
, CalendarYear nvarchar(50) Not Null
);
go

Declare @StartDate date; 
Declare @EndDate date;

SET @StartDate = '01/01/1951'
SET @EndDate = '12/31/2019'

Declare @DateInProcess datetime 
SET @DateInProcess = @StartDate;

While @DateInProcess <= @EndDate
	Begin
		Insert Into [dbo].[DimDates] 
		( [CalendarDateKey]
		, [CalendarDateName]
		, [CalendarYear]
		)
		Values ( 
		  Convert(nvarchar(50), @DateInProcess, 112) -- [CalendarDateKey]
		, DateName( weekday, @DateInProcess ) + ', ' + Convert(nvarchar(50), @DateInProcess, 110) --  [CalendarDateName] 
		, Cast( Year( @DateInProcess) as nVarchar(50) ) -- [CalendarYear]
		);  
		-- Add a day and loop again
		Set @DateInProcess = DateAdd(d, 1, @DateInProcess);
	End
go

select * from pams.dbo.DimDates

--Creating Dimension Table Countries

If (OBJECT_ID('DimCountries') IS NOT NULL) DROP TABLE DimCountries;
go

CREATE 
TABLE dbo.DimCountries
(
	[CountryID] int Not Null CONSTRAINT [pkDimCountires] PRIMARY KEY,
	[Country] nvarchar(50) NULL,
	[2letterISO] nvarchar(5) NULL,
	[3letterISO] nvarchar(5) NULL,
	[3digitcode] int NULL
)

--Creating Dimension Table Enduselist

If (OBJECT_ID('DimEndUseList') IS NOT NULL) DROP TABLE DimEndUseList;
go

CREATE 
TABLE dbo.DimEndUseList
(
	[EndUseID] int NOT NULL CONSTRAINT [pkDimEndUseList] PRIMARY KEY,
	[EndUseName] nvarchar(80) NULL
)	 

--Creating Dimension Table Technologylist

If (OBJECT_ID('DimTechnologylist') IS NOT NULL) DROP TABLE DimTechnologylist;
go

CREATE 
TABLE dbo.DimTechnologylist
(
	[TechID] int NOT NULL CONSTRAINT [pkDimTechList] PRIMARY KEY,
	[TechName] nvarchar(80) NULL
)

--Creating Dimension Table Sectorlist

If (OBJECT_ID('DimSectorlist') IS NOT NULL) DROP TABLE DimSectorlist;
go

CREATE 
TABLE dbo.DimSectorlist
(
	[SectorID] int NOT NULL CONSTRAINT [pkDimSectorList] PRIMARY KEY,
	[SectorName] nvarchar(80) NULL
)

--Creating Dimension Table Sectorlist

If (OBJECT_ID('DimPolicyTypelist') IS NOT NULL) DROP TABLE DimPolicyTypelist;
go

CREATE 
TABLE dbo.DimPolicyTypelist
(
	[PolicyTypeID] int NOT NULL CONSTRAINT [pkDimPolicyTypelist] PRIMARY KEY,
	[PolicyTypeName] nvarchar(80) NULL
)

--Creating Dimension Table Currency
If (OBJECT_ID('DimCurrency') IS NOT NULL) DROP TABLE DimCurrency;
go

CREATE 
TABLE DimCurrency
(
	[CurrencyID] int NOT NULL CONSTRAINT [pDimCurrency] PRIMARY KEY,
	[CurrencyName] nvarchar(80) NULL,
    [CurrencyNum] int NULL
)

--Creating fact Table EUIDdefiner
If (OBJECT_ID('factEUIDdefiner') IS NOT NULL) DROP TABLE factEUIDdefiner;
go

CREATE 
TABLE factEUIDdefiner
(
	[EUID] int NOT NULL,
	[SectorID] int NOT NULL,
    [EndUseID] int NOT NULL,
	[TechID] int NOT NULL,
	[ETPEndUseName] nvarchar(80) NULL
)

--Defining foreign key constraints to fetch names for Sector, Enduse and Tech

ALTER TABLE factEUIDdefiner ADD CONSTRAINT 
FK_SectorID FOREIGN KEY (SectorID) REFERENCES DimSectorlist(SectorID);
  
ALTER TABLE factEUIDdefiner ADD CONSTRAINT 
FK_EndUseID FOREIGN KEY (EndUseID) REFERENCES DimEndUseList(EndUseID);

ALTER TABLE factEUIDdefiner ADD CONSTRAINT 
FK_TechID FOREIGN KEY (TechID) REFERENCES DimTechnologyList(TechID);


--Creating Dimension Table States

If (OBJECT_ID('DimStates') IS NOT NULL) DROP TABLE DimStates;
go

CREATE 
TABLE DimStates
(
	[StateID] nvarchar(9) CONSTRAINT [pkstates] PRIMARY KEY NOT NULL,
	[2letterISO] nvarchar(2) NOT NULL,
	[StateName] nvarchar(50) NULL,
)

--Select DimCountries.Country, count(DimStates.StateName) as Number
--from DimStates 
--	right join DimCountries on 
--			   DimStates.[2letterISO]=DimCountries.[2letterISO]
--group by DimCountries.Country

If (OBJECT_ID('[FactDimPolicies]') IS NOT NULL) DROP TABLE FactDimPolicies;
go

--Combining the Dimension table Policies and the fact table so that the number of tables can be reduced 

CREATE 
TABLE FactDimPolicies
(	
	[POL-ID] varchar(9) NOT NULL CONSTRAINT PkDimpolicies PRIMARY KEY,
	[Nid] varchar(9) NULL,
	[Year] varchar(6) NULL,
	[Jurisdiction] varchar(25) NULL,
	[Title] varchar(255) NOT NULL,
	[Policy_info] varchar(max) NULL,
	[DatePromulgated] date NULL,
	[Superseded_by_ID] varchar(9) NULL,
	[YearEnded] varchar(6) NULL,
	[Status] varchar(255) NULL,
	[DateAdded] Date NULL,
	[Mandatory] varchar(5) NULL,
	[BudgetAllocated] varchar(255) NULL,
	[BudgetStartYear] varchar(6) NULL,
	[BudgetEndYear] varchar(6) NULL,
	[DateModified] datetime NULL,
	[PolicyTypeID] int NOT NULL,
	[SectorID] int NOT NULL,
	[CountryID] int Not Null,
	[EndUseID] int NOT NULL,
	[TechID] int NOT NULL,
	[CurrencyID] int NOT NULL,
	[StateID] nvarchar(9) NOT NULL,
	CONSTRAINT FKpolicyTypefact FOREIGN KEY ([PolicyTypeID]) REFERENCES dbo.DimPolicyTypelist,
	CONSTRAINT FKcountryfact FOREIGN KEY ([CountryID]) REFERENCES dbo.DimCountries,
	CONSTRAINT FKsectorfact FOREIGN KEY ([SectorID]) REFERENCES dbo.DimSectorlist,
	CONSTRAINT FKendusefact FOREIGN KEY ([EndUseID]) REFERENCES dbo.DimEndUseList,
	CONSTRAINT FKTechfact FOREIGN KEY ([TechID]) REFERENCES dbo.DimTechnologylist,
	CONSTRAINT FKCurrencyfact FOREIGN KEY ([CurrencyID]) REFERENCES dbo.DimCurrency,
	CONSTRAINT FKStatefact FOREIGN KEY ([StateID]) REFERENCES dbo.DimStates
)

--??question on currency id
-- Creating the bridge table between policy and policy type

If (OBJECT_ID('BridgePolicyType') IS NOT NULL) DROP TABLE BridgePolicyType;
go

CREATE 
TABLE BridgePolicyType
( 
	[PolicyTypeID] int NOT NULL,
	[POL-ID] varchar(9) NOT NULL,
	CONSTRAINT PKBridgePolicyType PRIMARY KEY ([PolicyTypeID],[POL-ID]),
	CONSTRAINT FKpolicy FOREIGN KEY ([POL-ID]) REFERENCES FactDimPolicies,
	CONSTRAINT FKpolicyType FOREIGN KEY ([PolicyTypeID]) REFERENCES dbo.DimPolicyTypelist
)

-- Creating the bridge table between policy and sector

If (OBJECT_ID('BridgeSector') IS NOT NULL) DROP TABLE BridgeSector;
go

CREATE 
TABLE BridgeSector
( 
	[SectorID] int NOT NULL,
	[POL-ID] varchar(9) NOT NULL,
	CONSTRAINT PKBridgeSector PRIMARY KEY ([SectorID],[POL-ID]),
	CONSTRAINT FKpolicysector FOREIGN KEY ([POL-ID]) REFERENCES FactDimPolicies,
	CONSTRAINT FKSectorName FOREIGN KEY ([SectorID]) REFERENCES dbo.DimSectorlist
)

-- Creating the bridge table between policy and Enduse

If (OBJECT_ID('BridgeEnduse') IS NOT NULL) DROP TABLE BridgeEnduse;
go

CREATE 
TABLE BridgeEnduse
( 
	[EndUseID] int NOT NULL,
	[POL-ID] varchar(9) NOT NULL,
	CONSTRAINT PKBridgeEndUse PRIMARY KEY ([EndUseID],[POL-ID]),
	CONSTRAINT FKpolicyEnduse FOREIGN KEY ([POL-ID]) REFERENCES FactDimPolicies,
	CONSTRAINT FKEnduseName FOREIGN KEY ([EndUseID]) REFERENCES dbo.DimEndUseList
)

-- Creating the bridge table between policy and Technology

If (OBJECT_ID('BridgeTech') IS NOT NULL) DROP TABLE BridgeTech;
go

CREATE 
TABLE BridgeTech
( 
	[TechID] int NOT NULL,
	[POL-ID] varchar(9) NOT NULL,
	CONSTRAINT PKBridgetech PRIMARY KEY ([TechID],[POL-ID]),
	CONSTRAINT FKpolicyTech FOREIGN KEY ([POL-ID]) REFERENCES FactDimPolicies,
	CONSTRAINT FKtechName FOREIGN KEY ([TechID]) REFERENCES dbo.DimTechnologylist
)

-- Creating the bridge table between policy and Country

If (OBJECT_ID('BridgeCountry') IS NOT NULL) DROP TABLE BridgeCountry;
go

CREATE 
TABLE BridgeCountry
( 
	[CountryID] int NOT NULL,
	[POL-ID] varchar(9) NOT NULL,
	CONSTRAINT PKBridgeCountry PRIMARY KEY ([CountryID],[POL-ID]),
	CONSTRAINT FKpolicyCountry FOREIGN KEY ([POL-ID]) REFERENCES FactDimPolicies,
	CONSTRAINT FKCountryName FOREIGN KEY ([CountryID]) REFERENCES dbo.DimCountries
)

--To find out countries with their respective currencys

--select DimCountries.Country, DimCurrency.CurrencyName
--from FactDimPolicies 
--	inner join DimCountries on DimCountries.CountryID = FactDimPolicies.CountryID
--	inner join DimCurrency on DimCurrency.CurrencyID = FactDimPolicies.CurrencyID