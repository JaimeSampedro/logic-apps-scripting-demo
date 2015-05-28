CREATE TABLE [dbo].[Orders] (
    [ID]        INT          IDENTITY (1, 1) NOT NULL,
    [ItemName]  VARCHAR (50) NULL,
    [Quantity]  INT          NULL,
    [UnitPrice] FLOAT (53)   NULL,
    [IsRead]    BIT          NULL,
    PRIMARY KEY CLUSTERED ([ID] ASC)
);

