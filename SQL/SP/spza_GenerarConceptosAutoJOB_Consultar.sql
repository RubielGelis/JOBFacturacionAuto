IF OBJECT_ID('dbo.spza_GenerarConceptosAutoJOB_Consultar', 'P') IS NOT NULL
    DROP PROCEDURE dbo.spza_GenerarConceptosAutoJOB_Consultar;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE PROCEDURE [dbo].[spza_GenerarConceptosAutoJOB_Consultar]
	-- Parametros del procedimiento
	@id_usuario			INT,
	@dt_fechaFactura	SMALLDATETIME	= NULL,
	@tasa_usd			MONEY			= 1	,
	@ZML_DatosXML		VARCHAR(MAX)	= NULL  
 
AS
BEGIN
	-- SET NOCOUNT ON: Previene que conjuntos de resultados extras interfieran con 
	-- expresiones SELECT
	SET NOCOUNT ON;

    -- Declaracion e inicializacion de variables
  	DECLARE @bl_permit			 BIT 	, -- Permiso de ejecucion del proceso
  			@bl_as 	   			 BIT	, -- Auditar exito
	 		@bl_af 			     BIT	, -- Auditar fallido	 		
			@procmsg	VARCHAR(8000)	, -- Mensaje devuelto por procedimientos llamados desde este procedimiento
			@procret 	BIT 			, -- Valor de retorno de los procedimientos llamados desde este procedimiento
			@idproce	int		    	, -- Codigo de proceso
	 		@retry 		BIT			    , -- 1=Reintentar ; 0=Abortar  
	 		@retrycont	INT			    , -- Contador de reintentos
	 		@maxretries INT			    , -- Maximo numero de reintentos
	 		@timeout	NVARCHAR(4000)  , -- Tiempo de espera maximo por bloqueo de registros
	 		@stmt 		NVARCHAR(4000)  , -- Cadena de instrucciones T-SQL
			@msg	    VARCHAR(8000)   , -- Mensaje retornado por el sistema
			@retval		TINYINT 		, -- Valor de retorno de este procedimiento: 0:Exito ; 1:Error(Bloque Catch)
			@Prefijo As Varchar(50)		, --Prefijo para indicar si es Dolares o Pesos
			@am_Contado MONEY			,
			@am_Credito MONEY			,
			@MonedaLocal Varchar(3)		,
			@TruncarDecimales Varchar(1),
			@IdMonedaLocal INT			,
			@bl_tomarFPAirplusTkt BIT	,
			@bl_tomarFPTaoTkt BIT;

	SELECT 	@retry				 = 1 		   ,
			@retrycont			 = 0		   ,
			@retval				 = 0;
  	
  	-- Manejo de tiempo de espera y de reintentos por bloqueo de tablas/registros  
   	SELECT @maxretries = convert(INT,Valor) FROM dbo.Parametros WHERE Id = 60 ;
	SELECT @timeout    = convert(NVARCHAR(4000),Valor) FROM dbo.Parametros WHERE Id = 50 ;		
	SET @stmt = N'SET LOCK_TIMEOUT '+ltrim(rtrim(@timeout))
	EXEC sp_executesql @stmt,N''
	
	Select @TruncarDecimales = Valor From parametros Where Id = 521

	WHILE ( (@retry = 1) AND (@retrycont <= @maxretries) )
	BEGIN
		SET @retry = 0;
    
    	-- Bloque TRY
    	BEGIN TRY 
    	    		
    		--Obteniendo informacion de seguridad y auditoria--
			/*EXEC dbo.spzaProcesoUsuario_Consultar @id_usuario   = @id_usuario       ,
												  @id_proceso   = @idproce 		    , 
												  @bl_permit    = @bl_permit OUTPUT , 
												  @bl_auditsuc  = @bl_as 	 OUTPUT , 
												  @bl_auditfail = @bl_af 	 OUTPUT ;
			IF (@bl_permit = 0)
			BEGIN 
				SELECT 'No posee permisos suficientes para ejecutar esta acciÃ³n.' AS 'Respuesta'
				RETURN @retval;
			END */

			
			
			--Instrucciones del procedimiento-----------------------------------------
			DECLARE @NumeroDecimales INT
			SELECT  @NumeroDecimales = Valor from parametros where Id = 33

			Select @MonedaLocal = Valor From parametros where id=10
			Select @IdMonedaLocal =  Id From Monedas_iata Where cd_codigo=@MonedaLocal

			DECLARE @PaisLocal VARCHAR(50)
			SELECT @PaisLocal = Valor From parametros where id=240

			DECLARE @bl_utilizarcencostosuc BIT,@bl_utilizarcencostoimp BIT
			SELECT @bl_utilizarcencostosuc = CASE WHEN RTRIM(LTRIM(Valor))='S' THEN 1 ELSE 0 END From parametros where id=134
			SELECT @bl_utilizarcencostoimp = CASE WHEN RTRIM(LTRIM(Valor))='S' THEN 1 ELSE 0 END From parametros where id=137
			SET @bl_utilizarcencostosuc = ISNULL(@bl_utilizarcencostosuc,0)
			SET @bl_utilizarcencostoimp = ISNULL(@bl_utilizarcencostoimp,0)

			SELECT @bl_tomarFPAirplusTkt = CASE WHEN rtrim(ltrim(Valor))='S' THEN 1 ELSE 0 END  FROM dbo.Parametros where Id=608
			SELECT @bl_tomarFPTaoTkt = CASE WHEN rtrim(ltrim(Valor))='S' THEN 1 ELSE 0 END  FROM dbo.Parametros where Id=609
			SET @bl_tomarFPAirplusTkt=ISNULL(@bl_tomarFPAirplusTkt,0)
			SET @bl_tomarFPTaoTkt=isnull(@bl_tomarFPTaoTkt,0)

			IF OBJECT_ID('tempdb..#Concepto') IS NOT NULL DROP TABLE #Concepto;
			CREATE TABLE #Concepto 
			(Id INT IDENTITY
			,cd_cliente VARCHAR(25) COLLATE DATABASE_DEFAULT
			,id_conceptofacturacion INT
            ,id_tiposservicios INT
            ,in_nacionalidad INT
			,id_aerolinea	INT
			,id_moneda	INT
            ,ds_paxname VARCHAR(30) COLLATE DATABASE_DEFAULT
            ,ds_paxape VARCHAR(30) COLLATE DATABASE_DEFAULT
            ,cd_paxtype CHAR(3) COLLATE DATABASE_DEFAULT
            ,ds_paxClasificacion CHAR(6) COLLATE DATABASE_DEFAULT
			,cd_tiquete CHAR(11) COLLATE DATABASE_DEFAULT
			,cd_proveedores VARCHAR(25) COLLATE DATABASE_DEFAULT
			,dt_llegada SMALLDATETIME
			,dt_salida SMALLDATETIME
			,cd_cencosto VARCHAR(16) COLLATE DATABASE_DEFAULT
			,cd_auxiliar VARCHAR(16) COLLATE DATABASE_DEFAULT
			,cd_item VARCHAR(16) COLLATE DATABASE_DEFAULT
			,CodigoReserva VARCHAR(25) COLLATE DATABASE_DEFAULT
			,am_tarifa MONEY
			,am_total MONEY
			,ColId VARCHAR(25) COLLATE DATABASE_DEFAULT
			,cd_Consecutivo_depende VARCHAR(50) COLLATE DATABASE_DEFAULT
			,am_ValorComision MONEY
			,am_ImpuestoComision MONEY
			,am_totalfactura MONEY
			,cd_tourcode VARCHAR(25) COLLATE DATABASE_DEFAULT
			,am_Contado MONEY --rgelis 2017/02/11 req.47323
			,am_Credito MONEY --rgelis 2017/02/11 req.47323
			,cd_tktrevisado VARCHAR(14) COLLATE DATABASE_DEFAULT --inicio rgelis 2017/09/19 req.5282
			,id_TiposDocumento INT
            ,cd_Penalidad VARCHAR(14) COLLATE DATABASE_DEFAULT
			,cd_TipoTiqueteGDS VARCHAR(3) COLLATE DATABASE_DEFAULT --fin rgelis 2017/09/19 req.5282
			,am_TasaCambio MONEY --rgelis 2017/10/25 req.54014
			,ds_itinerario VARCHAR(123) COLLATE DATABASE_DEFAULT --rgelis 2018/04/16 req.57446
			,id_sucursal INT --inicio rgelis 2018/05/07 req.58559
			,id_implante INT
			,id_FormasPago INT 
			,cd_TarjetasCredito VARCHAR(4) COLLATE DATABASE_DEFAULT --fin rgelis 2018/05/07 req.58559
			,iden_gds INT
			,cd_codigotc VARCHAR(2) COLLATE DATABASE_DEFAULT
			,ds_numerotc VARCHAR(25) COLLATE DATABASE_DEFAULT
			,ds_vencetc VARCHAR(5) COLLATE DATABASE_DEFAULT
			,ds_autorizaciontc VARCHAR(25) COLLATE DATABASE_DEFAULT
			,ds_vouchertc VARCHAR(25) COLLATE DATABASE_DEFAULT
			,in_cuotastc INT
			,id_FormasPagoTAO INT 
			,cd_codigotcTAO VARCHAR(2) COLLATE DATABASE_DEFAULT
			,ds_numerotcTAO VARCHAR(25) COLLATE DATABASE_DEFAULT
			,ds_vencetcTAO VARCHAR(5) COLLATE DATABASE_DEFAULT
			,ds_autorizaciontcTAO VARCHAR(25) COLLATE DATABASE_DEFAULT
			,ds_vouchertcTAO VARCHAR(25) COLLATE DATABASE_DEFAULT
			,in_cuotastcTAO INT 
			)
			
			DECLARE @ExecSQL VARCHAR(MAX) = 'INSERT INTO #Concepto ' + @ZML_DatosXML;
			EXEC(@ExecSQL);
			--select * from #Concepto
			--RETURN 1
			
			-- Loop variables
			DECLARE @cur_cd_cliente VARCHAR(25),
					@cur_id_conceptofacturacion INT,
					@cur_in_nacionalidad INT,
					@cur_id_aerolinea INT,
					@cur_id_moneda INT,
					@cur_ds_paxname VARCHAR(30),
					@cur_ds_paxape VARCHAR(30),
					@cur_cd_paxtype CHAR(3),
					@cur_ds_paxClasificacion CHAR(6),
					@cur_cd_tiquete CHAR(11),
					@cur_dt_llegada SMALLDATETIME,
					@cur_dt_salida SMALLDATETIME,
					@cur_cd_cencosto VARCHAR(16),
					@cur_cd_auxiliar VARCHAR(16),
					@cur_cd_item VARCHAR(16),
					@cur_CodigoReserva VARCHAR(25),
					@cur_id_sucursal INT,
					@cur_id_implante INT,
					@cur_id_FormasPago INT,
					@cur_cd_TarjetasCredito VARCHAR(4),
					@cur_id_TarjetasCredito INT,
					@cur_iden_gds INT,
					@cur_ColId VARCHAR(25),
					@cur_cd_Consecutivo_depende VARCHAR(50),
					@cur_cd_codigotc VARCHAR(2), 
					@cur_ds_numerotc VARCHAR(25),
					@cur_ds_vencetc VARCHAR(5),
					@cur_ds_autorizaciontc VARCHAR(25), 
					@cur_ds_vouchertc VARCHAR(25), 
					@cur_in_cuotastc INT,
					@cur_id_FormasPagoTAO INT,
					@cur_id_TarjetasCreditoTAO INT,
					@cur_cd_codigotcTAO VARCHAR(2),
					@cur_ds_numerotcTAO VARCHAR(25),
					@cur_ds_vencetcTAO VARCHAR(5),
					@cur_ds_autorizaciontcTAO VARCHAR(25),
					@cur_ds_vouchertcTAO VARCHAR(25),
					@cur_in_cuotastcTAO INT

			DECLARE @cur_id_reserva_int INT;

			DECLARE @OriginalConcepto TABLE 
			(
			 cd_cliente VARCHAR(25)
			,id_conceptofacturacion INT
            ,in_nacionalidad INT
			,id_aerolinea	INT
			,id_moneda	INT
            ,ds_paxname VARCHAR(30)
            ,ds_paxape VARCHAR(30)
            ,cd_paxtype CHAR(3)
            ,ds_paxClasificacion CHAR(6)
			,cd_tiquete CHAR(11)
			,dt_llegada SMALLDATETIME
			,dt_salida SMALLDATETIME
			,cd_cencosto VARCHAR(16)
			,cd_auxiliar VARCHAR(16)
			,cd_item VARCHAR(16)
			,CodigoReserva VARCHAR(25)
			,id_sucursal INT
			,id_implante INT
			,id_FormasPago INT 
			,cd_TarjetasCredito VARCHAR(4)
			,iden_gds INT
			,ColId VARCHAR(25)
			,cd_Consecutivo_depende VARCHAR(50)
			,cd_codigotc VARCHAR(2) 
			,ds_numerotc VARCHAR(25)
			,ds_vencetc VARCHAR(5)
			,ds_autorizaciontc VARCHAR(25) 
			,ds_vouchertc VARCHAR(25) 
			,in_cuotastc INT
			,id_FormasPagoTAO INT
			,cd_codigotcTAO VARCHAR(2)
			,ds_numerotcTAO VARCHAR(25)
			,ds_vencetcTAO VARCHAR(5)
			,ds_autorizaciontcTAO VARCHAR(25)
			,ds_vouchertcTAO VARCHAR(25)
			,in_cuotastcTAO INT
			)

			INSERT INTO @OriginalConcepto (cd_cliente, id_conceptofacturacion, in_nacionalidad, id_aerolinea, id_moneda, ds_paxname, ds_paxape, cd_paxtype, ds_paxClasificacion, cd_tiquete, dt_llegada, dt_salida, cd_cencosto, cd_auxiliar, cd_item, CodigoReserva, id_sucursal, id_implante, id_FormasPago, cd_TarjetasCredito, iden_gds, ColId, cd_Consecutivo_depende, cd_codigotc, ds_numerotc, ds_vencetc, ds_autorizaciontc, ds_vouchertc, in_cuotastc, id_FormasPagoTAO, cd_codigotcTAO, ds_numerotcTAO, ds_vencetcTAO, ds_autorizaciontcTAO, ds_vouchertcTAO, in_cuotastcTAO)
			SELECT cd_cliente, id_conceptofacturacion, in_nacionalidad, id_aerolinea, id_moneda, ds_paxname, ds_paxape, cd_paxtype, ds_paxClasificacion, cd_tiquete, dt_llegada, dt_salida, cd_cencosto, cd_auxiliar, cd_item, CodigoReserva, id_sucursal, id_implante, id_FormasPago, cd_TarjetasCredito, iden_gds, ColId, cd_Consecutivo_depende, cd_codigotc, ds_numerotc, ds_vencetc, ds_autorizaciontc, ds_vouchertc, in_cuotastc, id_FormasPagoTAO, cd_codigotcTAO, ds_numerotcTAO, ds_vencetcTAO, ds_autorizaciontcTAO, ds_vouchertcTAO, in_cuotastcTAO 
			FROM #Concepto
			
			--select * from @OriginalConcepto
			--return 1
			-- 1. Construir @ListaReservas
			DECLARE @ListaReservas VARCHAR(MAX) = '';
			SELECT @ListaReservas = @ListaReservas + CAST(id_reserva AS VARCHAR) + ',' 
			FROM (
				SELECT DISTINCT r.id AS id_reserva 
				FROM dbo.ReservasGDS r 
				INNER JOIN #Concepto c ON r.cd_codigo = c.CodigoReserva
			) X;
			IF LEN(@ListaReservas) > 0 SET @ListaReservas = LEFT(@ListaReservas, LEN(@ListaReservas) - 1);

			-- 2. Cargar Itinerarios y FEEs Masivamente
			IF OBJECT_ID('tempdb..#ItinerariosJob') IS NOT NULL DROP TABLE #ItinerariosJob;
			CREATE TABLE #ItinerariosJob (id INT, id_reserva INT, orden INT, cd_origen VARCHAR(10), cd_destino VARCHAR(10), cd_clase VARCHAR(10), fecha_salida VARCHAR(20), hora_salida VARCHAR(10), hora_llegada VARCHAR(10), terminal VARCHAR(50), cd_aero_siglas VARCHAR(10), cd_farebasis VARCHAR(50), ds_NumVuelo VARCHAR(50), ds_TipoVuelo VARCHAR(50), am_valor MONEY, bl_NoUtilizado BIT, am_co2 MONEY);
			
			IF OBJECT_ID('tempdb..#FeesJob') IS NOT NULL DROP TABLE #FeesJob;
			CREATE TABLE #FeesJob (id_reserva INT, cd_tiquete VARCHAR(50), in_orden INT, cd_conceptofac VARCHAR(50), cd_subcodigo VARCHAR(50), am_valor MONEY, ds_servicio VARCHAR(200));
																																
			IF ISNULL(@ListaReservas,'') <> ''
			BEGIN 
				INSERT INTO #ItinerariosJob EXEC dbo.spza_ReservasGDSJOB_Itinerario @id_reserva = @ListaReservas;
				INSERT INTO #FeesJob EXEC dbo.spza_ReservasGDS_FEEJOB_Consultar @Id_Reservas = @ListaReservas;
			END
			
			DECLARE cur_conceptos CURSOR LOCAL FAST_FORWARD FOR
			SELECT cd_cliente, id_conceptofacturacion, in_nacionalidad, id_aerolinea, id_moneda, ds_paxname, ds_paxape, cd_paxtype, ds_paxClasificacion, cd_tiquete, dt_llegada, dt_salida, cd_cencosto, cd_auxiliar, cd_item, CodigoReserva, id_sucursal, id_implante, id_FormasPago, cd_TarjetasCredito, iden_gds, ColId, cd_Consecutivo_depende, cd_codigotc, ds_numerotc, ds_vencetc, ds_autorizaciontc, ds_vouchertc, in_cuotastc, id_FormasPagoTAO, cd_codigotcTAO, ds_numerotcTAO, ds_vencetcTAO, ds_autorizaciontcTAO, ds_vouchertcTAO, in_cuotastcTAO 
			FROM @OriginalConcepto

			OPEN cur_conceptos
			FETCH NEXT FROM cur_conceptos INTO @cur_cd_cliente, @cur_id_conceptofacturacion, @cur_in_nacionalidad, @cur_id_aerolinea, @cur_id_moneda, @cur_ds_paxname, @cur_ds_paxape, @cur_cd_paxtype, @cur_ds_paxClasificacion, @cur_cd_tiquete, @cur_dt_llegada, @cur_dt_salida, @cur_cd_cencosto, @cur_cd_auxiliar, @cur_cd_item, @cur_CodigoReserva, @cur_id_sucursal, @cur_id_implante, @cur_id_FormasPago, @cur_cd_TarjetasCredito, @cur_iden_gds, @cur_ColId, @cur_cd_Consecutivo_depende, @cur_cd_codigotc, @cur_ds_numerotc, @cur_ds_vencetc, @cur_ds_autorizaciontc, @cur_ds_vouchertc, @cur_in_cuotastc, @cur_id_FormasPagoTAO, @cur_cd_codigotcTAO, @cur_ds_numerotcTAO, @cur_ds_vencetcTAO, @cur_ds_autorizaciontcTAO, @cur_ds_vouchertcTAO, @cur_in_cuotastcTAO

			WHILE @@FETCH_STATUS = 0
			BEGIN
				SELECT @cur_id_reserva_int = id FROM dbo.ReservasGDS WHERE cd_codigo = @cur_CodigoReserva

				IF @cur_id_reserva_int IS NOT NULL
				BEGIN
					-- 1. Consultar itinerario y actualizar en @Concepto
					DECLARE @ItinTable TABLE (
						id INT, id_reserva INT, orden INT, cd_origen VARCHAR(10), cd_destino VARCHAR(10),
						cd_clase VARCHAR(10), fecha_salida VARCHAR(20), hora_salida VARCHAR(10),
						hora_llegada VARCHAR(10), terminal VARCHAR(50), cd_aero_siglas VARCHAR(10),
						cd_farebasis VARCHAR(50), ds_NumVuelo VARCHAR(50), ds_TipoVuelo VARCHAR(50),
						am_valor MONEY, bl_NoUtilizado BIT, am_co2 MONEY
					)
					DELETE FROM @ItinTable

					INSERT INTO @ItinTable
					SELECT id, id_reserva, orden, cd_origen, cd_destino, cd_clase, fecha_salida, hora_salida, hora_llegada, terminal, cd_aero_siglas, cd_farebasis, ds_NumVuelo, ds_TipoVuelo, am_valor, bl_NoUtilizado, am_co2
					FROM #ItinerariosJob WHERE id_reserva = @cur_id_reserva_int;

					DECLARE @ds_itinerario VARCHAR(123) = ''
					SELECT @ds_itinerario = CASE WHEN @ds_itinerario = '' THEN cd_origen + '-' + cd_destino ELSE @ds_itinerario + '-' + cd_destino END
					FROM @ItinTable
					ORDER BY orden

					IF @ds_itinerario <> ''
					BEGIN
						UPDATE #Concepto
						SET ds_itinerario = @ds_itinerario
						WHERE cd_tiquete = @cur_cd_tiquete AND CodigoReserva = @cur_CodigoReserva
					END

					-- 2. Consultar FEEs/cargos adicionales por tiquete (solo si es tiquete, id_conceptofacturacion 1 o 2)
					IF @cur_id_conceptofacturacion IN (1, 2)
					BEGIN
						DECLARE @FeeTable TABLE (
							id_reserva INT,
							cd_tiquete VARCHAR(50),
							in_orden INT,
							cd_conceptofac VARCHAR(50),
							cd_subcodigo VARCHAR(50),
							am_valor MONEY,
							ds_servicio VARCHAR(200)
						)
						DELETE FROM @FeeTable

						INSERT INTO @FeeTable
						SELECT id_reserva, cd_tiquete, in_orden, cd_conceptofac, cd_subcodigo, am_valor, ds_servicio
						FROM #FeesJob WHERE id_reserva = @cur_id_reserva_int 
						AND (cd_tiquete = @cur_cd_tiquete OR cd_tiquete = CASE WHEN LEN(@cur_cd_tiquete)>=13 THEN RIGHT(@cur_cd_tiquete,LEN(@cur_cd_tiquete)-3) ELSE @cur_cd_tiquete END);

						SELECT @cur_id_TarjetasCredito = id FROM dbo.TarjetasCredito WHERE cd_codigo=@cur_cd_TarjetasCredito
						SELECT @cur_id_TarjetasCreditoTAO = id FROM dbo.TarjetasCredito WHERE cd_codigo=@cur_cd_codigotcTAO

						INSERT INTO #GenerarConceptosAuto (
							id_ConceptoFacturacion,
							cd_ConceptoFacturacion,
							ds_ConceptoFacturacion,
							id_TiposConceptFac,
							bl_contorlarCargImp,
							bl_CalculoAutoValoresFacturacion,
							id_TiposServicio,
							cd_TiposServicio,
							ds_TiposServicio,
							cd_proveedores,
							ds_proveedores,
							cd_tiquete,
							ds_servicio,
							ds_descrip,
							ds_paxname,
							ds_paxape,
							cd_paxtype,
							ds_paxClasificacion,
							in_nacionalidad,
							dt_llegada,
							dt_salida,
							cd_cencosto,
							cd_auxiliar,
							cd_item,
							Valor,
							am_Contado,
							am_Credito,
							ColId,
							cd_Consecutivo_depende,
							CodigoReserva,
							am_ImpuestoComision,
							Respuesta,
							bl_RutaExentaIva,
							id_FormasPago,
							id_TarjetasCredito,
							am_basedescuento,
							am_pordescuento,
							id_FormasPagoAirPlus,
							cd_FormasPagoAirPlus,
							ds_FormasPagoAirPlus,
							id_TarjetasCreditoAirPlus,
							cd_TarjetasCreditoAirPlus,
							ds_numerotarjetaAirPlus,
							cd_codigotc, 
							ds_numerotc,
							ds_vencetc, 
							ds_autorizaciontc,
							ds_vouchertc, 
							in_cuotastc 
						)
						SELECT 
							id_ConceptoFacturacion=C.id,
							cd_ConceptoFacturacion=C.cd_codigo,
							ds_ConceptoFacturacion=C.ds_nombre,
							id_TiposConceptFac=C.id_TiposConceptoFacturacion,
							bl_contorlarCargImp=C.bl_contorlarCargImp,
							bl_CalculoAutoValoresFacturacion=C.bl_CalculoAutoValoresFacturacion,
							id_TiposServicio=TS.id,
							cd_TiposServicio=TS.cd_codigo,
							ds_TiposServicio=TS.ds_nombre,
							cd_proveedores='',
							ds_proveedores='',
							cd_tiquete=F.cd_tiquete,
							ds_servicio=F.ds_servicio,
							ds_descrip=F.ds_servicio,
							ds_paxname=@cur_ds_paxname,
							ds_paxape=@cur_ds_paxape,
							cd_paxtype=@cur_cd_paxtype,
							ds_paxClasificacion=@cur_ds_paxClasificacion,
							in_nacionalidad=@cur_in_nacionalidad,
							dt_llegada=@cur_dt_llegada,
							dt_salida=@cur_dt_salida,
							cd_cencosto=@cur_cd_cencosto,
							cd_auxiliar=@cur_cd_auxiliar,
							cd_item=@cur_cd_item,
							Valor=F.am_valor,
							am_Contado=CASE WHEN ISNULL(@cur_id_FormasPago,0)<>2 THEN F.am_valor ELSE 0 END,
							am_Credito=CASE WHEN ISNULL(@cur_id_FormasPago,0)=2 THEN F.am_valor ELSE 0 END,
							ColId=@cur_ColId,
							cd_Consecutivo_depende=@cur_cd_Consecutivo_depende,
							CodigoReserva=@cur_CodigoReserva,
							am_ImpuestoComision=0,
							Respuesta='',
							bl_RutaExentaIva=0,
							id_FormasPago=@cur_id_FormasPago,
							id_TarjetasCredito=@cur_id_TarjetasCredito,
							am_basedescuento=0,
							am_pordescuento=0,
							id_FormasPagoAirPlus=NULL,
							cd_FormasPagoAirPlus='',
							ds_FormasPagoAirPlus='',
							id_TarjetasCreditoAirPlus=NULL,
							cd_TarjetasCreditoAirPlus='',
							ds_numerotarjetaAirPlus='',
							cd_codigotc=@cur_cd_codigotc, 
							ds_numerotc=@cur_ds_numerotc,
							ds_vencetc=@cur_ds_vencetc, 
							ds_autorizaciontc=@cur_ds_autorizaciontc,
							ds_vouchertc=@cur_ds_vouchertc, 
							in_cuotastc=@cur_in_cuotastc
						FROM @FeeTable F
						INNER JOIN dbo.ConceptoFacturacion C ON C.cd_codigo = F.cd_conceptofac
						LEFT JOIN dbo.TiposServicios TS ON TS.cd_codigo = F.cd_subcodigo

						-- Auto-TAO Configuration
						DECLARE @AUTOTAO CHAR(1) = (SELECT LTRIM(RTRIM(Valor)) FROM dbo.Parametros WHERE id = 192);
						DECLARE @AUTOTAOAMADEUS CHAR(1) = (SELECT LTRIM(RTRIM(Valor)) FROM dbo.Parametros WHERE id = 213);
						
						DECLARE @ValorTAO MONEY = 0;
						
						-- Validar si el cliente tiene config especial
						DECLARE @bl_TAO BIT, @am_TarifaOneWay MONEY, @am_TarifaRoundTrip MONEY, @am_Tarifa_USD300 MONEY, @am_Tarifa_USD300_USD500 MONEY, @am_Tarifa_USD500_USD800 MONEY, @am_Tarifa_USD800 MONEY;
						SELECT TOP 1 @bl_TAO = ISNULL(bl_TAO,0), @am_TarifaOneWay = am_TarifaOneWay, @am_TarifaRoundTrip = am_TarifaRoundTrip, @am_Tarifa_USD300 = am_Tarifa_USD300, @am_Tarifa_USD300_USD500 = am_Tarifa_USD300_USD500, @am_Tarifa_USD500_USD800 = am_Tarifa_USD500_USD800, @am_Tarifa_USD800 = am_Tarifa_USD800
						FROM dbo.Configuracion_remisiones WHERE id_cliente = @cur_cd_cliente;

						IF @bl_TAO = 1 OR @AUTOTAO = 'S' OR (@AUTOTAOAMADEUS = 'S' AND @cur_iden_gds = 2)
						BEGIN
							IF ISNULL(@bl_TAO, 0) = 0
							BEGIN
								-- Cargar de parametros generales
								SELECT @am_TarifaOneWay = CAST(Valor AS MONEY) FROM dbo.Parametros WHERE id = 61;
								SELECT @am_TarifaRoundTrip = CAST(Valor AS MONEY) FROM dbo.Parametros WHERE id = 62;
								SELECT @am_Tarifa_USD300 = CAST(Valor AS MONEY) FROM dbo.Parametros WHERE id = 67;
								SELECT @am_Tarifa_USD300_USD500 = CAST(Valor AS MONEY) FROM dbo.Parametros WHERE id = 68;
								SELECT @am_Tarifa_USD500_USD800 = CAST(Valor AS MONEY) FROM dbo.Parametros WHERE id = 69;
								SELECT @am_Tarifa_USD800 = CAST(Valor AS MONEY) FROM dbo.Parametros WHERE id = 70;
							END

							-- Determinar rango basado en nacionalidad e itinerario
							DECLARE @tarifa_base MONEY;
							SELECT @tarifa_base = am_tarifa FROM #Concepto WHERE cd_tiquete = @cur_cd_tiquete AND CodigoReserva = @cur_CodigoReserva;

							IF @cur_in_nacionalidad = 1
							BEGIN
								IF dbo.fnza_ItinerarioTipo(@ds_itinerario) = 'OW' SET @ValorTAO = @am_TarifaOneWay;
								ELSE SET @ValorTAO = @am_TarifaRoundTrip;
							END
							ELSE
							BEGIN
								-- Convertir a USD si aplica, aquÃ­ usamos la tarifa base por simplicidad
								DECLARE @TarifaUSD MONEY = ISNULL(@tarifa_base, 0); 
								IF @TarifaUSD <= 300 SET @ValorTAO = @am_Tarifa_USD300;
								ELSE IF @TarifaUSD <= 500 SET @ValorTAO = @am_Tarifa_USD300_USD500;
								ELSE IF @TarifaUSD <= 800 SET @ValorTAO = @am_Tarifa_USD500_USD800;
								ELSE SET @ValorTAO = @am_Tarifa_USD800;
							END

							IF ISNULL(@ValorTAO, 0) > 0
							BEGIN
								INSERT INTO #GenerarConceptosAuto (
										id_ConceptoFacturacion,
										cd_ConceptoFacturacion,
										ds_ConceptoFacturacion,
										id_TiposConceptFac,
										bl_contorlarCargImp,
										bl_CalculoAutoValoresFacturacion,
										id_TiposServicio,
										cd_TiposServicio,
										ds_TiposServicio,
										cd_proveedores,
										ds_proveedores,
										cd_tiquete,
										ds_servicio,
										ds_descrip,
										ds_paxname,
										ds_paxape,
										cd_paxtype,
										ds_paxClasificacion,
										in_nacionalidad,
										dt_llegada,
										dt_salida,
										cd_cencosto,
										cd_auxiliar,
										cd_item,
										Valor,
										am_Contado,
										am_Credito,
										ColId,
										cd_Consecutivo_depende,
										CodigoReserva,
										am_ImpuestoComision,
										Respuesta,
										bl_RutaExentaIva,
										id_FormasPago,
										id_TarjetasCredito,
										am_basedescuento,
										am_pordescuento,
										id_FormasPagoAirPlus,
										cd_FormasPagoAirPlus,
										ds_FormasPagoAirPlus,
										id_TarjetasCreditoAirPlus,
										cd_TarjetasCreditoAirPlus,
										ds_numerotarjetaAirPlus,
										cd_codigotc, 
										ds_numerotc,
										ds_vencetc, 
										ds_autorizaciontc,
										ds_vouchertc, 
										in_cuotastc
								)
								SELECT
										id_ConceptoFacturacion=@cur_in_nacionalidad+3,
										cd_ConceptoFacturacion=CASE WHEN @cur_in_nacionalidad=2 THEN 'CAI' ELSE 'CAN' END,
										ds_ConceptoFacturacion='Tarifa Adminstrativa '+CASE WHEN @cur_in_nacionalidad=2 THEN 'Internacional' ELSE 'Nacional' END,
										id_TiposConceptFac=3,
										bl_contorlarCargImp=0,
										bl_CalculoAutoValoresFacturacion=0,
										id_TiposServicio=NULL,
										cd_TiposServicio='',
										ds_TiposServicio='',
										cd_proveedores='',
										ds_proveedores='',
										cd_tiquete=@cur_cd_tiquete,
										ds_servicio='Tarifa Adminstrativa '+CASE WHEN @cur_in_nacionalidad=2 THEN 'Internacional' ELSE 'Nacional' END + ' Tiquete: ' + ISNULL(@cur_cd_tiquete,''),
										ds_descrip='Tarifa Adminstrativa '+CASE WHEN @cur_in_nacionalidad=2 THEN 'Internacional' ELSE 'Nacional' END + ' Tiquete: ' + ISNULL(@cur_cd_tiquete,''),
										ds_paxname=@cur_ds_paxname,
										ds_paxape=@cur_ds_paxape,
										cd_paxtype=@cur_cd_paxtype,
										ds_paxClasificacion=@cur_ds_paxClasificacion,
										in_nacionalidad=@cur_in_nacionalidad,
										dt_llegada=@cur_dt_llegada,
										dt_salida=@cur_dt_salida,
										cd_cencosto=@cur_cd_cencosto,
										cd_auxiliar=@cur_cd_auxiliar,
										cd_item=@cur_cd_item,
										Valor=@ValorTAO,
										am_Contado=CASE WHEN (CASE WHEN ISNULL(@cur_id_FormasPagoTAO,0)<>0 THEN ISNULL(@cur_id_FormasPagoTAO,0) ELSE ISNULL(@cur_id_FormasPago,0) END)<>2 THEN @ValorTAO ELSE 0 END,
										am_Credito=CASE WHEN (CASE WHEN ISNULL(@cur_id_FormasPagoTAO,0)<>0 THEN ISNULL(@cur_id_FormasPagoTAO,0) ELSE ISNULL(@cur_id_FormasPago,0) END)=2 THEN @ValorTAO ELSE 0 END,
										ColId=@cur_ColId,
										cd_Consecutivo_depende=@cur_cd_Consecutivo_depende,
										CodigoReserva=@cur_CodigoReserva,
										am_ImpuestoComision=0,
										Respuesta='',
										bl_RutaExentaIva=0,
										id_FormasPago=CASE WHEN ISNULL(@cur_id_FormasPagoTAO,0)<>0 THEN @cur_id_FormasPagoTAO ELSE @cur_id_FormasPago END,
										id_TarjetasCredito=CASE WHEN ISNULL(@cur_id_TarjetasCreditoTAO,0)<>0 THEN @cur_id_TarjetasCreditoTAO ELSE @cur_id_TarjetasCredito END,
										am_basedescuento=0,
										am_pordescuento=0,
										id_FormasPagoAirPlus=NULL,
										cd_FormasPagoAirPlus='',
										ds_FormasPagoAirPlus='',
										id_TarjetasCreditoAirPlus=NULL,
										cd_TarjetasCreditoAirPlus='',
										ds_numerotarjetaAirPlus='',
										cd_codigotc=CASE WHEN ISNULL(@cur_cd_codigotcTAO,'')<>'' THEN @cur_cd_codigotcTAO ELSE @cur_cd_codigotc END, 
										ds_numerotc=CASE WHEN ISNULL(@cur_ds_numerotcTAO,'')<>'' THEN @cur_ds_numerotcTAO ELSE @cur_ds_numerotc END,
										ds_vencetc=CASE WHEN ISNULL(@cur_ds_vencetcTAO,'')<>'' THEN @cur_ds_vencetcTAO ELSE @cur_ds_vencetc END, 
										ds_autorizaciontc=CASE WHEN ISNULL(@cur_ds_autorizaciontcTAO,'')<>'' THEN @cur_ds_autorizaciontcTAO ELSE @cur_ds_autorizaciontc END,
										ds_vouchertc=CASE WHEN ISNULL(@cur_ds_vouchertcTAO,'')<>'' THEN @cur_ds_vouchertcTAO ELSE @cur_ds_vouchertc END, 
										in_cuotastc=CASE WHEN ISNULL(@cur_in_cuotastcTAO,0)<>0 THEN @cur_in_cuotastcTAO ELSE @cur_in_cuotastc END
							END
						END
					END
					
					-- 3. Consultar servicios adicionales de la tabla ReservaGDS_Servicios
					/*
					INSERT INTO #Concepto (
						cd_cliente, id_conceptofacturacion, id_tiposservicios, in_nacionalidad,
						id_aerolinea, id_moneda, ds_paxname, ds_paxape, cd_paxtype, ds_paxClasificacion,
						cd_tiquete, cd_proveedores, dt_llegada, dt_salida, cd_cencosto, cd_auxiliar, cd_item,
						CodigoReserva, am_tarifa, am_total, ColId, cd_Consecutivo_depende,
						am_ValorComision, am_ImpuestoComision, am_totalfactura, cd_tourcode,
						am_Contado, am_Credito, cd_tktrevisado, id_TiposDocumento, cd_Penalidad,
						cd_TipoTiqueteGDS, am_TasaCambio, ds_itinerario, id_sucursal, id_implante,
						id_FormasPago, cd_TarjetasCredito, iden_gds
					)
					SELECT 
						@cur_cd_cliente,
						CASE WHEN cd_conceptofacturacion = 'CAN' THEN 4
							 WHEN cd_conceptofacturacion = 'CAI' THEN 5
							 ELSE 3 END,
						NULL,
						ISNULL(in_nacionalidad, @cur_in_nacionalidad),
						@cur_id_aerolinea,
						@cur_id_moneda,
						ISNULL(ds_pax_firstnm, @cur_ds_paxname),
						ISNULL(ds_pax_lastnm, @cur_ds_paxape),
						ISNULL(ds_pax_prefix, @cur_cd_paxtype),
						@cur_ds_paxClasificacion,
						@cur_cd_tiquete,
						cd_proveedores,
						ISNULL(dt_checkout, @cur_dt_llegada),
						ISNULL(dt_checkin, @cur_dt_salida),
						@cur_cd_cencosto,
						ISNULL(cd_auxiliar, @cur_cd_auxiliar),
						@cur_cd_item,
						@cur_CodigoReserva,
						am_tarifa,
						am_tarifa + ISNULL(am_iva, 0),
						CAST(id AS VARCHAR(25)),
						@cur_cd_tiquete,
						ISNULL(am_Comision, 0), 0, am_tarifa + ISNULL(am_iva, 0), NULL,
						ISNULL(am_TarifaContado, 0) + ISNULL(am_IvaContado, 0) + ISNULL(am_OtrosContado, 0),
						ISNULL(am_TarifaCredito, 0) + ISNULL(am_IvaCredito, 0) + ISNULL(am_OtrosCredito, 0),
						NULL, NULL, NULL,
						NULL, 1.0, NULL, @cur_id_sucursal, @cur_id_implante,
						@cur_id_FormasPago, @cur_cd_TarjetasCredito, @cur_iden_gds
					FROM dbo.ReservaGDS_Servicios
					WHERE id_reserva = @cur_id_reserva_int AND ISNULL(bl_anulado, 0) = 0
					*/
				END

				IF @@ERROR <> 0
					BREAK

				FETCH NEXT FROM cur_conceptos INTO @cur_cd_cliente, @cur_id_conceptofacturacion, @cur_in_nacionalidad, @cur_id_aerolinea, @cur_id_moneda, @cur_ds_paxname, @cur_ds_paxape, @cur_cd_paxtype, @cur_ds_paxClasificacion, @cur_cd_tiquete, @cur_dt_llegada, @cur_dt_salida, @cur_cd_cencosto, @cur_cd_auxiliar, @cur_cd_item, @cur_CodigoReserva, @cur_id_sucursal, @cur_id_implante, @cur_id_FormasPago, @cur_cd_TarjetasCredito, @cur_iden_gds, @cur_ColId, @cur_cd_Consecutivo_depende, @cur_cd_codigotc, @cur_ds_numerotc, @cur_ds_vencetc, @cur_ds_autorizaciontc, @cur_ds_vouchertc, @cur_in_cuotastc, @cur_id_FormasPagoTAO, @cur_cd_codigotcTAO, @cur_ds_numerotcTAO, @cur_ds_vencetcTAO, @cur_ds_autorizaciontcTAO, @cur_ds_vouchertcTAO, @cur_in_cuotastcTAO
			END
			CLOSE cur_conceptos
			DEALLOCATE cur_conceptos
			
			SET @msg = 'Conceptos Automaticos Generados Exitosamente'

			--SELECT *
			--	   ,ltrim(rtrim(@msg)) AS 'Respuesta'  
			--FROM #Concepto

			UPDATE c
			SET c.cd_cliente = NULL 
			from #Concepto c
			LEFT JOIN ConfiguracionConceptosAutoClientes ccac ON ccac.cd_cliente = c.cd_cliente
			WHERE ccac.id is NULL 

			Select @NumeroDecimales = 2
			From #Concepto c
			inner JOIN Configuracion_remisiones cr ON cr.id_cliente = c.cd_cliente
			where  bl_decimales_TAO_ConceptoAuto = 1


			INSERT INTO #GenerarConceptosAuto SELECT DISTINCT id_ConceptoFacturacion, cd_ConceptoFacturacion, ds_ConceptoFacturacion, id_TiposConceptFac, bl_contorlarCargImp, bl_CalculoAutoValoresFacturacion, id_TiposServicio, cd_TiposServicio, ds_TiposServicio, cd_proveedores, ds_proveedores, cd_tiquete, ds_servicio, ds_descrip, ds_paxname, ds_paxape, cd_paxtype, ds_paxClasificacion, in_nacionalidad, dt_llegada, dt_salida, cd_cencosto, cd_auxiliar, cd_item
			, Valor 
			, am_Contado 
			, am_Credito
			, ColId, cd_Consecutivo_depende, CodigoReserva, am_ImpuestoComision, Respuesta ,bl_RutaExentaIva --rgelis 2018/04/16 req.57446
			, id_FormasPago, id_TarjetasCredito --rgelis 2018/05/08 req.58559
			,am_basedescuento, am_pordescuento
			,id_FormasPagoAirPlus
            ,cd_FormasPagoAirPlus 
            ,ds_FormasPagoAirPlus
            ,id_TarjetasCreditoAirPlus
            ,cd_TarjetasCreditoAirPlus
            ,ds_numerotarjetaAirPlus
			,cd_codigotc 
			,ds_numerotc
			,ds_vencetc 
			,ds_autorizaciontc
			,ds_vouchertc 
			,in_cuotastc
			From(
				SELECT id_ConceptoFacturacion
					  ,cd_ConceptoFacturacion
					  ,ds_ConceptoFacturacion
					  ,id_TiposConceptFac
					  ,bl_contorlarCargImp
					  ,bl_CalculoAutoValoresFacturacion
					  ,id_TiposServicio
					  ,cd_TiposServicio
					  ,ds_TiposServicio
					  ,cd_proveedores
					  ,ds_proveedores
					  ,cd_tiquete
					  ,ds_servicio
					  ,ds_descrip
					  ,ds_paxname
					  ,ds_paxape
					  ,cd_paxtype
					  ,ds_paxClasificacion
					  ,in_nacionalidad
					  ,dt_llegada
					  ,dt_salida
					  ,cd_cencosto
					  ,cd_auxiliar
					  ,cd_item
					  ,Valor			
					  ,am_Contado = CASE
											WHEN id_FormasPago = 1 THEN valor 
											WHEN am_Contado<>0 AND am_Credito<>0 THEN valor --inicio rgelis 2017/02/11 req.47323
				  							WHEN am_Contado<>0 AND am_Credito=0  THEN valor
				  							ELSE 0 END 
					  ,am_Credito = CASE	WHEN id_FormasPago = 1 THEN 0
											WHEN id_formaspago_padre = 2 THEN valor
											WHEN am_Contado=0 AND am_Credito<>0 THEN valor
				  							ELSE 0 END --fin rgelis 2017/02/11 req.47323	
					  ,ColId
					  ,cd_Consecutivo_depende
					  ,CodigoReserva 
					  ,am_ImpuestoComision
					  ,Respuesta 
					  ,Id_moneda
					  ,id_conceptofacturacionOrigen
					  ,bl_RutaExentaIva --rgelis 2018/04/16 req.57446
					  ,CASE WHEN id_FormasPago = 1 THEN id_FormasPago ELSE NULL END AS 'id_FormasPago'
					  ,NULL  'id_TarjetasCredito'  
					  ,am_basedescuento, am_pordescuento
					  ,id_FormasPagoAirPlus
					  ,cd_FormasPagoAirPlus 
					  ,ds_FormasPagoAirPlus
					  ,id_TarjetasCreditoAirPlus
					  ,cd_TarjetasCreditoAirPlus
					  ,ds_numerotarjetaAirPlus
					  ,cd_codigotc 
					  ,ds_numerotc
					  ,ds_vencetc 
					  ,ds_autorizaciontc
					  ,ds_vouchertc 
					  ,in_cuotastc
				FROM(
					SELECT	cfa.id As 'id_ConceptoFacturacion',
							cfa.cd_codigo As 'cd_ConceptoFacturacion',
							cfa.ds_nombre As 'ds_ConceptoFacturacion',
							cfa.id_TiposConceptoFacturacion As 'id_TiposConceptFac',
							cfa.bl_contorlarCargImp,
							1 AS 'bl_CalculoAutoValoresFacturacion',
							ts.id As 'id_TiposServicio',
							ts.cd_codigo  As 'cd_TiposServicio',
							ts.ds_nombre  As 'ds_TiposServicio',
							cf.cd_proveedores,
							P.RAZONCIAL AS 'ds_proveedores',
							cf.cd_tiquete,
							cfa.ds_nombre As 'ds_servicio',
							cfa.ds_descrip AS 'ds_descrip',
							cf.ds_paxname,
							cf.ds_paxape,
							cf.cd_paxtype,
							cf.ds_paxClasificacion,
							cf.in_nacionalidad,
							cf.dt_llegada,
							cf.dt_salida,
							cd_cencosto = CASE WHEN @bl_utilizarcencostoimp = 1 AND ISNULL(I.cd_cencosto,'')<>'' THEN I.cd_cencosto WHEN @bl_utilizarcencostosuc = 1 AND ISNULL(S.cd_cencosto,'')<>'' THEN S.cd_cencosto ELSE cf.cd_cencosto END,
							cf.cd_auxiliar,
							cf.cd_item,
							Valor=ROUND((CASE WHEN ISNULL(CCC.am_valor,0)<>0 THEN ROUND(CCC.am_valor * CASE WHEN cf.id_moneda <>cc.id_moneda THEN  
																															case when MI.cd_codigo='USD' AND dbo.fnza_Valor_Parametro(424)='N' 
																															THEN @tasa_usd 
																															ELSE  dbo.fnza_Get_TasaCambioDia(@dt_fechaFactura,MI.id_monedaContabilidad) END 
																							 ELSE 1 END
																							 ,@NumeroDecimales) 
										   WHEN cc.bl_Valor=1 AND cc.am_Valor>0 THEN ROUND( cc.am_Valor * CASE WHEN cf.id_moneda <>cc.id_moneda THEN  
																															case when MI.cd_codigo='USD' AND dbo.fnza_Valor_Parametro(424)='N' 
																															THEN @tasa_usd 
																															ELSE  dbo.fnza_Get_TasaCambioDia(@dt_fechaFactura,MI.id_monedaContabilidad) END 
																							 ELSE 1 END
																							 ,@NumeroDecimales)--rgelis 2016/07/22 correccion por redondeo
										   WHEN cc.bl_porcentaje = 1 AND cc.am_porcentaje>0 AND cc.in_tipobasecalcular=0 THEN ROUND((cf.am_tarifa*(cc.am_porcentaje/100)),@NumeroDecimales,case when @TruncarDecimales = 'S' then 1 else 0 end)
										   WHEN cc.bl_porcentaje = 1 AND cc.am_porcentaje>0 AND cc.in_tipobasecalcular=1 THEN ROUND((cf.am_total*(cc.am_porcentaje/100)),@NumeroDecimales,case when @TruncarDecimales = 'S' then 1 else 0 end)
										   WHEN cc.in_tipobasecalcular= 2  THEN cf.am_ValorComision
										   WHEN cc.bl_porcentaje = 1 AND cc.am_porcentaje>0 AND cc.in_tipobasecalcular=3 THEN ROUND((cf.am_totalfactura*(cc.am_porcentaje/100)),@NumeroDecimales,case when @TruncarDecimales = 'S' then 1 else 0 end) 
										   WHEN	cc.bl_rango = 1 AND cc.in_tipobasecalcular=0 THEN dbo.fnza_ValorConceptoAutoRango(c.id,cc.id,cfa.id,cf.am_tarifa)
										   WHEN	cc.bl_rango = 1 AND cc.in_tipobasecalcular=1 THEN dbo.fnza_ValorConceptoAutoRango(c.id,cc.id,cfa.id,cf.am_total) 
										   ELSE 0 
									  END) / CASE WHEN cf.id_moneda <> @IdMonedaLocal AND cf.id_moneda <> cc.id_moneda AND dbo.fnza_Valor_Parametro(504)='S' AND cf.id_conceptofacturacion IN(1,2) AND ISNULL(cf.am_TasaCambio,0)<>0 THEN cf.am_TasaCambio ELSE 1 END --rgelis 2017/10/25/ req.54014
										   * CASE WHEN cf.id_moneda = @IdMonedaLocal AND cf.id_moneda <> cc.id_moneda AND cc.bl_rango = 1 AND ISNULL(@tasa_usd,0)>1 AND dbo.fnza_Valor_Parametro(504)<>'S' AND @PaisLocal='Colombia' THEN @tasa_usd ELSE 1 END,@NumeroDecimales),
							cf.ColId,
							cf.cd_Consecutivo_depende,
							cf.CodigoReserva, 
							am_ImpuestoComision = CASE WHEN cc.in_tipobasecalcular = 2 THEN cf.am_ImpuestoComision ELSE 0 END,
							cf.am_Contado, --rgelis 2017/02/11 req.47323
							cf.am_Credito, --rgelis 2017/02/11 req.47323 
							ltrim(rtrim(@msg)) AS 'Respuesta' ,
							cc.id_moneda,
							c.id_conceptofacturacion As 'id_conceptofacturacionOrigen',
							CASE WHEN c.id_conceptofacturacion IN (1,2) THEN dbo.fnza_RutaTktExentaIva(cf.ds_itinerario) ELSE 0 END AS 'bl_RutaExentaIva', --rgelis 2018/04/16 req.57446
							CFP.id_FormasPago,
							CFP.id_TarjetasCredito,
							CFP.ds_NumeroTarjetasCredito AS 'ds_NumeroTarjetasCredito',
							ISNULL(TC.ds_tcnumber,'') AS 'ds_NumeroTarjetasCreditoGDS',
							id_formaspago_padre = cf.id_formaspago,
							am_basedescuento = 	CASE 
													WHEN cc.bl_porcentaje = 1 AND cc.am_porcentaje>0 AND cc.in_tipobasecalcular=0 THEN cf.am_tarifa
													WHEN cc.bl_porcentaje = 1 AND cc.am_porcentaje>0 AND cc.in_tipobasecalcular=1 THEN cf.am_total
													ELSE 0
												END,
							am_pordescuento = CASE WHEN cc.bl_porcentaje = 1  THEN cc.am_porcentaje ELSE 0 END,
							id_FormasPagoAirPlus = CASE WHEN FPTAO.Id IS NOT NULL THEN FPTAO.Id
														WHEN tcA.Id IS NOT NULL AND cap.id IS NOT NULL THEN cap.Id_FormasPago ELSE NULL END,
							cd_FormasPagoAirPlus = CASE WHEN FPTAO.Id IS NOT NULL THEN FPTAO.cd_codigo
														WHEN tcA.Id IS NOT NULL AND cap.id IS NOT NULL THEN fpap.cd_codigo ELSE NULL END,
							ds_FormasPagoAirPlus = CASE  WHEN FPTAO.Id IS NOT NULL THEN FPTAO.ds_nombre
														WHEN tcA.Id IS NOT NULL AND cap.id IS NOT NULL THEN fpap.ds_nombre ELSE NULL END,
							id_TarjetasCreditoAirPlus = CASE WHEN FPTAO.Id IS NOT NULL AND tctao.id IS NOT NULL Then tctao.id
															 WHEN tcA.Id IS NOT NULL AND cap.id IS NOT NULL Then tcap.id ELSE NULL END,
							cd_TarjetasCreditoAirPlus = CASE WHEN FPTAO.Id IS NOT NULL AND tctao.id IS NOT NULL Then tctao.cd_codigo
															 WHEN tcA.Id IS NOT NULL AND cap.id IS NOT NULL Then tcap.cd_codigo ELSE NULL END,
							ds_numerotarjetaAirPlus = CASE WHEN FPTAO.Id IS NOT NULL AND tctao.id IS NOT NULL Then tkt.cd_NumeroTarjetaTAO
														   WHEN tcA.Id IS NOT NULL AND cap.id IS NOT NULL Then cap.ds_numerotarjeta ELSE NULL END,
							cd_codigotc = cf.cd_codigotc,
							ds_numerotc = cf.ds_numerotc,
							ds_vencetc = cf.ds_vencetc,
							ds_autorizaciontc = cf.ds_autorizaciontc,
							ds_vouchertc = cf.ds_vouchertc, 
							in_cuotastc = cf.in_cuotastc
					FROM dbo.ConfiguracionConceptosAutoClientes c
					INNER JOIN #Concepto cf ON (
												(
													ISNULL(cf.cd_cliente,'') = ISNULL(c.cd_cliente,'') 
													OR (ISNULL(c.cd_cliente,'')='' /*AND ISNULL(cf.cd_cliente,'')=''*/) 
												) 
												AND (
														ISNULL(cf.id_conceptofacturacion,0)=ISNULL(c.id_conceptofacturacion,0) 
														OR (ISNULL(c.id_conceptofacturacion,0)=0 AND ISNULL(cf.id_conceptofacturacion,0)=0)
													)
												AND (
														ISNULL(cf.id_tiposservicios,0)=ISNULL(c.id_tiposservicios,0) 
														OR ISNULL(c.id_tiposservicios,0)=0 --AND ISNULL(cf.id_tiposservicios,0)=0)
													) 
												AND (
														ISNULL(cf.in_nacionalidad,3)=ISNULL(c.in_nacionalidad,3) OR ISNULL(c.in_nacionalidad,3)=3
													)
												AND (
														ISNULL(cf.id_aerolinea,0)=ISNULL(c.id_Aerolinea,0) OR ISNULL(c.id_Aerolinea,0)=0
													)
												AND (
														ISNULL(cf.cd_tourcode,'')=ISNULL(c.cd_tourcode,'') OR ISNULL(c.cd_tourcode,'')=''
													)
												AND (
														ISNULL(cf.id_FormasPago,0)=ISNULL(c.id_formaspago,0) OR ISNULL(c.id_formaspago,0)=0
													)
												AND (
														ISNULL(cf.id_moneda,0)=ISNULL(c.id_moneda,0) OR ISNULL(c.id_moneda,0)=0
													)
												)
					LEFT JOIN dbo.TiposDocumento td ON td.id = cf.id_TiposDocumento --inicio rgelis 2017/09/19 req.52820
					LEFT JOIN dbo.ConfiguracionConceptosAutoClientes_Conceptos cc ON ((cc.id_ConfiguracionConceptosAutoClientes=c.id AND cc.bl_Activo = 1)
																					  AND ((c.id_conceptofacturacion IN (1,2) 
																							AND ((ISNULL(cf.cd_tktrevisado,'')<>'' AND cc.in_revisado=1) 
																								 OR (ISNULL(cf.cd_tktrevisado,'')='' AND cc.in_revisado=2) 
																								 OR cc.in_revisado in (0,3)
																								)
																							AND (((ISNULL(td.bl_EMD,0)=1 OR ISNULL(cf.cd_Penalidad,'')<>'' OR ISNULL(cf.cd_TipoTiqueteGDS,'') = 'EMD') AND cc.in_EMD=1) 
																								 OR ((ISNULL(td.bl_EMD,0)=0 AND ISNULL(cf.cd_Penalidad,'')='' AND ISNULL(cf.cd_TipoTiqueteGDS,'') <> 'EMD') AND cc.in_EMD=2) 
																								 OR cc.in_EMD in (0,3)
																								)
																							AND (((dbo.fnza_RutaTktExentaIva(cf.ds_itinerario)=1) AND cc.in_Exento=1) --inicio rgelis 2018/04/16 req.57446 
																								 OR ((dbo.fnza_RutaTktExentaIva(cf.ds_itinerario)=0) AND cc.in_Exento=2) 
																								 OR cc.in_Exento in (0,3)
																								) --fin rgelis 2018/04/16 req.57446 
																							AND (((dbo.fnza_ItinerarioTipo(cf.ds_itinerario)='OW') AND cc.in_Tipoitinerario=1 AND cc.bl_Tipoitinerario=1) --inicio --rgelis 2019/09/27 req.103215 
																								 OR ((dbo.fnza_ItinerarioTipo(cf.ds_itinerario)='RT') AND cc.in_Tipoitinerario=2 AND cc.bl_Tipoitinerario=1) 
																								 OR (cc.in_Tipoitinerario in (0,3) AND cc.bl_Tipoitinerario=1)
																								 OR cc.bl_Tipoitinerario=0
																								) --fin rgelis 2019/09/27 req.103215 	
																						   )
																						   OR c.id_conceptofacturacion NOT IN (1,2)
																						  )
																					   AND (
																							 (ISNULL(cc.id_sucursal,0) = ISNULL(cf.id_sucursal,0) or ISNULL(cc.id_sucursal,0) = 0)
																							 AND (ISNULL(cc.id_implante,0) = ISNULL(cf.id_implante,0) or ISNULL(cc.id_implante,0) = 0) 
																						   )
																					 ) --fin rgelis 2017/09/19 req.52820
					LEFT JOIN dbo.ConceptoFacturacion cfa ON cfa.id=cc.id_conceptofacturacion
					LEFT JOIN dbo.tiposServicio_asignados tsa ON (tsa.id_ConceptoFacturacion = cfa.id AND tsa.bl_Valdeft = 1) 
					LEFT JOIN dbo.TiposServicios ts ON ts.id = tsa.id_TipoServicio
					LEFT JOIN dbo.PROVEEDORES P ON P.IDPROVE = cfa.cd_proveedor
					LEFT JOIN dbo.Monedas_IATA MI ON MI.id = CC.id_moneda
					--LEFT JOIN dbo.ReservaGDS_Detalles rd on rd.ds_tkt_number = cf.cd_tiquete and cf.id_conceptofacturacion in (1,2)
					--LEFT JOIN dbo.TarjetasCredito TA ON TA.cd_codigo = CF.cd_TarjetasCredito
					OUTER APPLY dbo.fnza_ReservasGdsFormasPago_Table(cf.CodigoReserva,cf.cd_tiquete) AS TC
					LEFT JOIN dbo.ConfiguracioFacturaTarjetasPropias_NumerosTC CFP ON (CFP.ds_NumeroTarjetasCredito = tc.ds_tcnumber AND CFP.id_Sucursal = CF.id_sucursal AND ISNULL(CFP.id_implante,0) = ISNULL(CF.id_implante,0))
					--OUTER APPLY dbo.fnza_ReservasGdsFormasPago_Table(cf.CodigoReserva,cf.cd_tiquete) AS TC
					LEFT JOIN dbo.ConfiguracionClientesConceptos CCC ON CCC.id_conceptofacturacion=cc.id_conceptofacturacion AND CCC.Id_Cliente = c.cd_cliente AND CCC.bl_inactivo=0
					--LEFT JOIN dbo.ReservasGDS r ON r.cd_codigo = cf.CodigoReserva
					LEFT JOIN dbo.ReservaGDS_Detalles tkt ON tkt.ds_tkt_number = cf.cd_tiquete and cf.id_conceptofacturacion in (1,2)
					LEFT JOIN dbo.tarjetascredito tcA on tcA.cd_codigo = tkt.ds_cc_code AND (tcA.bl_airplus = 1 OR @bl_tomarFPAirplusTkt=1)
					LEFT JOIN dbo.Cliente_FP_AirPlus cap on cap.id_cliente = cf.cd_cliente
					LEFT JOIN dbo.tarjetascredito tcap on tcap.id=cap.Id_TarjetasCredito
					LEFT JOIN dbo.FormasPago fpap on fpap.id = cap.Id_FormasPago
					LEFT JOIN dbo.Sucursales S ON S.id = cf.id_sucursal
					LEFT JOIN dbo.Implantes I ON I.id=cf.id_implante
					LEFT JOIN dbo.FormasPago FPTAO ON FPTAO.cd_codigo=Tkt.cd_FormaPagoTAO AND @bl_tomarFPTaoTkt=1 
					LEFT JOIN dbo.tarjetascredito tctao on tctao.cd_codigo=tkt.cd_TarjetaCreditoTAO
					WHERE cc.id is NOT NULL 
					GROUP BY c.id,
							cc.id,
							cc.id_conceptofacturacion,
							cfa.id,
							cfa.id_TiposConceptoFacturacion,
							cfa.bl_contorlarCargImp,
							cf.cd_proveedores,
							P.RAZONCIAL,
							cf.cd_tiquete,
							cfa.cd_codigo,
							cfa.ds_nombre,
							cfa.ds_descrip,
							ts.id,
							ts.cd_codigo,
							ts.ds_nombre,
							cf.ds_paxname,
							cf.ds_paxape,
							cf.cd_paxtype,
							cf.ds_paxClasificacion,
							cf.in_nacionalidad,
							cf.dt_llegada,
							cf.dt_salida,
							cf.cd_cencosto,
							cf.cd_auxiliar,
							cf.cd_item,
							cf.am_tarifa,
							cf.am_total,
							cc.bl_Valor,
							cc.bl_porcentaje,
							cc.am_valor,
							cc.am_porcentaje,
							cc.bl_rango,
							cf.ColId,
							cc.bl_Activo,
							cc.in_tipobasecalcular,
							cf.cd_Consecutivo_depende,
							cf.CodigoReserva,
							cf.am_ValorComision,
							cf.am_ImpuestoComision,
							cf.am_totalfactura ,
							MI.id_monedaContabilidad  ,
							cc.id_moneda ,
							cf.id_moneda, 
							MI.cd_codigo,
							cf.am_Contado, --rgelis 2017/02/11 req.47323
							cf.am_Credito, --rgelis 2017/02/11 req.47323 
							cc.id_moneda,
							c.id_conceptofacturacion,
							cf.id_conceptofacturacion, --rgelis 2017/10/25 req.54014
							CF.am_TasaCambio, --rgelis 2017/10/25 req.54014
							cf.ds_itinerario, --rgelis 2018/04/16 req.57446
							CFP.id_FormasPago, --rgelis 2018/05/08 req.58559
							CFP.id_TarjetasCredito,
							CFP.ds_NumeroTarjetasCredito,
							TC.ds_tcnumber,
							cf.id_formaspago,
							CCC.am_valor,
							tcA.Id,
							cap.id,
							cap.Id_FormasPago, 
							fpap.cd_codigo,
							fpap.ds_nombre,
							tcap.id, 
							tcap.cd_codigo,
							cap.ds_numerotarjeta,
							S.cd_cencosto,
							I.cd_cencosto,
							FPTAO.Id,
							FPTAO.cd_codigo,
							FPTAO.ds_nombre,
							tctao.id,
							tctao.cd_codigo,
							tkt.cd_NumeroTarjetaTAO,
							cf.cd_codigotc,
							cf.ds_numerotc,
							cf.ds_vencetc,
							cf.ds_autorizaciontc,
							cf.ds_vouchertc, 
							cf.in_cuotastc
				) AS C
			 ) AS F			
			--------------------------------------------------------------------------
			
			
			--Determinando si se debe auditar el proceso exitoso
			/*IF (@bl_as = 1) 
			BEGIN 										
				EXEC dbo.spzaAuditoria_Insertar  @id_proceso = @idproce    ,
												 @id_usuario = @id_usuario ,
												 @cd_status  = 1           , 												 
												 @admsg      = NULL        ,
							 					 @msgparams  = @msg;
			END*/ 			 			
			--SELECT ltrim(rtrim(@msg)) AS 'Respuesta';
			RETURN @retval;
	    END TRY 
    
    	-- Bloque CATCH (Manejo de excepciones)
    	BEGIN CATCH 
 		
 			-- Tiempo de espera alcanzado --
		   IF ERROR_NUMBER() = 1222
		    BEGIN
      			SET @msg =  'No se pudo ejecutar el proceso. Tiempo de espera agotado.';
      			SET @retval = 1
      			
	   	        RAISERROR (@msg,16,125);
	   	       	--Se debe auditar proceso fallido
				/*IF (@bl_af = 1) EXEC dbo.spzaAuditoria_Insertar  @id_proceso = @idproce ,
													 			 @id_usuario = @id_usuario ,
													 			 @cd_status  = 0           , 
													 			 @admsg      = @msg	   ;*/				
	   	       RETURN @retval;
		    END
		    
		    -- Registro bloqueado / Conflicto de actualizacion
		    ELSE IF ERROR_NUMBER() IN (1205, 3960)
    		BEGIN	   	        
		       	SET @retry     = 1              ;
		       	SET @retrycont = @retrycont + 1 ; 

	    	 END
	    	 ELSE
		     BEGIN
		     	-- Error no manejado --
				IF (XACT_STATE() <> 0)
	   	        BEGIN 				
					SET @retval = 1;
  	 				SET @msg =	'Ha ocurrido un error. InformaciÃ³n para soporte tecnico:'			+ CHAR(13)+ CHAR(10) + CHAR(13)+ CHAR(10) +
							    'Numero: ' + isnull(CAST(ERROR_NUMBER()   AS VARCHAR(10)),'') 		+ CHAR(13)+ CHAR(10) + CHAR(13)+ CHAR(10) +
								'Mensaje: ' + isnull(ERROR_MESSAGE(),'') 					   		+ CHAR(13)+ CHAR(10) + CHAR(13)+ CHAR(10) +
							 	'Severidad: ' + isnull(CAST(ERROR_SEVERITY() AS VARCHAR(10)),'') 	+ CHAR(13)+ CHAR(10) + CHAR(13)+ CHAR(10) +
							 	'Estado: ' + isnull(CAST(ERROR_STATE()    AS VARCHAR(10)),'') 		+ CHAR(13)+ CHAR(10) + CHAR(13)+ CHAR(10) +
								'Procedimiento: ' + 'spza_GenerarConceptosAutoJOB_Consultar'		+ CHAR(13)+ CHAR(10) + CHAR(13)+ CHAR(10) +
								'Linea: ' + isnull(CAST(ERROR_LINE() 	   AS VARCHAR(10)),''); 							
		
					RAISERROR (@msg,16,126);
					--Se debe auditar proceso fallido
					/*IF (@bl_af = 1) EXEC dbo.spzaAuditoria_Insertar	@id_proceso = @idproce   ,
											 			 			@id_usuario = @id_usuario ,
											 			 			@cd_status  = 0           , 
											 			 			@admsg      = @msg	  ;*/				
					RETURN @retval;
	   	        END 
		     END
		END CATCH     
	END 
	
	IF (@retrycont>@maxretries) 
	BEGIN 
		SET @retval = 1
		SET @msg = 'No se pudo finalizar el proceso. Maximo numero de reintentos alcanzado.'
		--Se debe auditar proceso fallido
		/*IF (@bl_af = 1) EXEC dbo.spzaAuditoria_Insertar  @id_proceso = @idproce    ,
											 			 @id_usuario = @id_usuario ,
											 			 @cd_status  = 0           , 
											 			 @admsg      = @msg	   ;*/												 	   					   
  		RAISERROR (@msg,16,127);
  		RETURN @retval;
  	END   	
    
    RETURN @retval;
END
GO

