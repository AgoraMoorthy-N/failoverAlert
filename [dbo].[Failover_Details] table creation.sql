USE [DBA_Internal] /** Mention your database here **/ 
GO

/****** Object:  Table [dbo].[Failover_Details]    Script Date: 3/10/2025 9:16:15 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[Failover_Details](
	[object_name] [char](50) NULL,
	[event_timestamp] [datetime] NULL,
	[ag_name] [varchar](50) NULL,
	[previous_state] [char](100) NULL,
	[current_State] [char](100) NULL
) ON [PRIMARY]
GO

