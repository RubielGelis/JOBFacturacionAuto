IF OBJECT_ID('dbo.spza_GDSFacturacionAutoJOB_Consultar', 'P') IS NOT NULL
    DROP PROCEDURE dbo.spza_GDSFacturacionAutoJOB_Consultar;
GO

CREATE PROCEDURE [dbo].[spza_GDSFacturacionAutoJOB_Consultar]
	-- Parametros del procedimiento
	@id_usuario INT,
	@cd_sucursal VARCHAR(MAX) = '',
	@cd_implante VARCHAR(MAX) = '',
	@bl_factura INT = 1,
	@bl_cotizacion INT = 0
With Encryption
AS
BEGIN
	-- SET NOCOUNT ON: Previene que conjuntos de resultados extras interfieran con 
	-- expresiones SELECT
	SET NOCOUNT ON;
	DECLARE 
		@FiltrarSucursalFactAuto BIT
		,@FiltrarImplanteFactAuto BIT
		,@AgruparFacturasAutomaticasXCliente VARCHAR(1),@MaximoNumeroTktsFacturaAutomatica INT /*JARG - 2016/03/30 - R30713 - Bloqueo de Maximo (N) tkts por factura.*/		
		,@GenerarCotizacion BIT --rgelis 2018/04/09 req.56942
		,@SoloUtilizarConfgClienteFacAuto BIT --rgelis 2018/04/13 req.58321
	DECLARE  @TableResultVacio TABLE (	PNR VARCHAR (62),	Tipo VARCHAR (4),	Servicio VARCHAR (123),	Descrip VARCHAR (78),	id INT ,	iden_gds INT,	ds_fecha SMALLDATETIME,	cd_tiqueteador VARCHAR (6),	cd_vendedor CHAR (3),	cd_cliente CHAR (10),	am_highfare MONEY,	am_lowfare MONEY,	am_fare MONEY,	ds_reasoncode CHAR (2), ds_cliname VARCHAR (50),	ds_clidir VARCHAR (50),	ds_clicity VARCHAR (50),	ds_cliid CHAR (10),	ds_itinerario VARCHAR (250),	ds_clases VARCHAR (61),	in_nacionalidad TINYINT,	id_air INT ,	ds_pax_number TINYINT,	ds_pax_firstnm VARCHAR (30),	ds_pax_lastnm VARCHAR (30),	ds_pax_prefix CHAR (3),	ds_tkt_number CHAR (10),	ds_tkt_prefix CHAR (3),	ds_aero_code CHAR (3),	ds_moneda CHAR (3),	am_tarifa MONEY,	am_iva MONEY,	am_tua MONEY,	am_comb MONEY,	am_vat MONEY,	ds_cc_code CHAR (2),	ds_cc_number VARCHAR (25),	am_tao MONEY,	am_ivatao MONEY,	am_cap MONEY,	am_ivacap MONEY,	ds_cc_code2 CHAR (2),	ds_cc_number2 CHAR (16),	am_fp1 MONEY,	am_fp2 MONEY,	cd_tktrevisado VARCHAR (14),	am_TarifaContado MONEY,	am_IvaContado MONEY,	am_OtrosContado MONEY,	am_TarifaCredito MONEY,	am_IvaCredito MONEY,	am_OtrosCredito MONEY,	am_Comision MONEY,	cd_clitipodoc VARCHAR (100),	cd_clitipotercero CHAR (1),	ds_clirazoncial VARCHAR (250),	ds_cliname2 VARCHAR (60),	ds_clilastname VARCHAR (60),	ds_clilastname2 VARCHAR (60),	cd_clipais VARCHAR (25),	ds_clitel VARCHAR (25),	cd_TipoTransaccion VARCHAR (1),	Fecha_Salida SMALLDATETIME,	Fecha_Llegada SMALLDATETIME,	Id_Srv INT,	cd_conceptofacturacion INT,	cd_tiposervicio INT,	cd_proveedores INT,	ds_proveedores INT,	id_car INT,	dt_entrega INT,	in_cars INT,	cd_carcode INT,	cd_conf_car INT,	cd_citysalida INT,	dt_retorno INT,	cd_cartype INT,	cd_currency INT,	am_tarifacar INT,	cd_bookingsource INT,	cd_ratecode INT,	id_htl INT,	dt_checkin INT,	in_guests INT,	cd_confirmation INT,	cd_city INT,	cd_htlchain INT,	dt_checkout INT,	in_noches INT,	ds_htlname INT,	in_habs INT,	cd_bed INT,	cd_ratecode_htl INT,	cd_htlcur INT,	am_htltarifa INT,	cd_agcur INT,	am_agtarifa INT,	ds_dir1 INT,	ds_tel INT,	ds_fax INT,	cd_centrocosto VARCHAR (50),	NumTktConj INT,	Respuesta VARCHAR (1),	ds_solicita VARCHAR (200),	cd_pax_CC VARCHAR (20),	ds_lapsoviaje VARCHAR (50),	ds_archivo VARCHAR (250),	ds_Observaciones VARCHAR (8000),	ds_ClienteEmail VARCHAR (100),	cd_sucursal CHAR (5),	cd_implante CHAR (5),	bl_ClienteActualizar BIT,	bl_NotificacionMPD BIT,	cd_FormaPagoTAO VARCHAR (3),	cd_TarjetaCreditoTAO VARCHAR (4),	cd_NumeroTarjetaTAO VARCHAR (25),	cd_VencimientoTarjetaTAO CHAR (6),	cd_NumeroPolizaTAO VARCHAR (50),	cd_AnexoPolizaTAO VARCHAR (50),	am_PorDesFormaPagoTA NUMERIC (8, 4),	cd_Penalidad CHAR (14),	ds_cc_vence CHAR (5),	ds_cc_vence2 CHAR (5),	ds_cc_autorizacion INT,	ds_cc_autorizacion2 VARCHAR (25),	ds_cc_voucher INT,	ds_cc_voucher2 VARCHAR (10),	ds_AutorizacionTarjetaTAO INT,	ds_VoucherTarjetaTAO INT,	am_fptao MONEY,	in_cc_cuotas INT,	in_cc_cuotas2 INT,	in_cuotasTarjetaTAO INT,	cd_TipoTarifaTAO VARCHAR (25),	cd_TipoTiquete CHAR (3),	am_TasaCambio MONEY,	cd_tiqueteador_facturador CHAR (3),	bl_ahorro BIT,	in_CantidadTarifaTAO INT,	in_CantidadSegmentoTAO INT,	cd_tourcode VARCHAR (25),	ds_contrato VARCHAR (25),	cd_PasaportePax VARCHAR (25),	ds_itinerarioaerolinea VARCHAR (128),	ds_tkt_prefixIata CHAR (3),	ds_Evento VARCHAR (250),	cd_iata VARCHAR (25),	ds_aero_codeIata CHAR (3), cd_Ahorro CHAR (3) )	  /*rgelis 2016/09/09 req.33775*/
	DECLARE @TValorInterfazGDSParametro TABLE(id INT IDENTITY, id_GDS INT, id_sys_entidades INT, cd_codigo_maestro VARCHAR(50), cd_dato_maestro VARCHAR(500), ds_valor VARCHAR(500)) --rgelis 2019/10/10 req.92991

	SET	@FiltrarSucursalFactAuto = 0;
	SELECT @FiltrarSucursalFactAuto = CASE WHEN rtrim(ltrim(Valor))='S' THEN 1 ELSE 0 END  FROM dbo.Parametros where Id=426 /*JARG 2015/07/25 - filtrar por sucursal facturacion automatica -M&M*/
	SET	@FiltrarImplanteFactAuto = 0;
	SELECT @FiltrarImplanteFactAuto = CASE WHEN rtrim(ltrim(Valor))='S' THEN 1 ELSE 0 END  FROM dbo.Parametros where Id=426 /*JARG 2015/07/25 - filtrar por sucursal facturacion automatica -M&M*/

	IF ISNULL(@cd_sucursal,'')='' AND ISNULL(@cd_implante,'')=''
	BEGIN
		SET	@FiltrarSucursalFactAuto = 0;
		SET	@FiltrarImplanteFactAuto = 0;
	END

	SELECT @AgruparFacturasAutomaticasXCliente = Valor FROM dbo.Parametros WHERE Id = 445
	SELECT @MaximoNumeroTktsFacturaAutomatica = Valor FROM dbo.Parametros WHERE Id = 446
	SELECT 
		@GenerarCotizacion = CASE WHEN rtrim(ltrim(Valor))='S' THEN 1 ELSE 0 END FROM dbo.Parametros WHERE Id = 526 --rgelis 2018/04/09 req.56942
		AND @bl_cotizacion = 1 --JRamirez 20200609
	
	SET @SoloUtilizarConfgClienteFacAuto=0
	SELECT @SoloUtilizarConfgClienteFacAuto = CASE WHEN rtrim(ltrim(Valor))='S' THEN 1 ELSE 0 END FROM dbo.Parametros WHERE Id = 525 --rgelis 2018/04/13 req.58321
	--IF NOT EXISTS(  SELECT r.id  
	--				FROM dbo.ReservasGDS r
	--				INNER JOIN dbo.ReservaGDS_Detalles tkt ON (r.id=tkt.id_reserva)
	--				INNER JOIN dbo.ReservasGDS_FacAuto fpa ON fpa.id_reserva = r.id
	--				WHERE tkt.bl_usada = 0 	AND (fpa.cd_sucursal = @cd_sucursal  OR @FiltrarSucursalFactAuto = 0)
	--				)
	--BEGIN
	--	SELECT * FROM @TableResultVacio
	--	RETURN 1
	--END

	/*
	DECLARE @Parametro INT
	SET @Parametro = 5

	SELECT 
		Cliente + '-'  + CONVERT(VARCHAR,(ROW_NUMBER()   OVER(PARTITION BY Cliente ORDER BY Cliente DESC)-1) / @MaximoNumeroTktsFacturaAutomatica)
		, Tiquete 
		,Contador=ROW_NUMBER()   OVER(PARTITION BY Cliente ORDER BY Cliente DESC)
		, Agrupado = (ROW_NUMBER()   OVER(PARTITION BY Cliente ORDER BY Cliente DESC)-1) / @Parametro
	FROM #Reservas 
	*/
	
	INSERT INTO @TValorInterfazGDSParametro(id_GDS,id_sys_entidades,cd_codigo_maestro,cd_dato_maestro,ds_valor)
	SELECT id_GDS				=	I.id_GDS
		  ,id_sys_entidades		=	E.id_sys_entidades
		  ,cd_codigo_maestro	=	E.cd_codigo_maestro
		  ,cd_dato_maestro		=	E.cd_dato_maestro
		  ,ds_valor				=	E.cd_codigo_equivalente
	FROM dbo.Interfaces_Equivalencia E
		INNER JOIN dbo.Interfaces I ON I.id = E.id_Interfaces


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
			@tc			INT 			, -- Numero de transacciones abiertas
			@msg	    VARCHAR(8000)   , -- Mensaje retornado por el sistema
			@retval		TINYINT 		, -- Valor de retorno de este procedimiento: 0:Exito ; 1:Error(Bloque Catch)
			@bl_BSP     BIT				, -- Solo trabaja con BSP
			@bl_tomarvendedorcliente BIT, -- Filtro para tomar vendedor del cliente /*rgelis 2014/12/18 - Toma el vendedor del cliente -EVT*/
			@bl_TomarSucursalImplantePCCGDS BIT,
			@TomarTC_Voucher_Auto_ZeusTC BIT,
			@bl_GenerarFacturaXTiquete BIT,
			@bl_tomarnacionalidadDetalles BIT,
			@bl_tomartiposervicionacionalidad BIT,
			@cd_tiposervicionacional VARCHAR(3),
			@cd_tiposerviciointernacional VARCHAR(3),
			@cd_TCTipoTarjetaMostrarNumero VARCHAR(3),
			@bl_tomarFPAirplusTkt BIT,
			@bl_tomarFPTaoTkt BIT;
	
	SELECT 	@idproce 			 = 123,
			@retry				 = 1 		   ,
			@retrycont			 = 0		   ,
			@tc 			 	 = @@TRANCOUNT ,
			@retval				 = 0;
  	
  	-- Manejo de tiempo de espera y de reintentos por bloqueo de tablas/registros  
   	SELECT @maxretries = 3
	SELECT @timeout    = 3000
	SET @stmt = N'SET LOCK_TIMEOUT '+ltrim(rtrim(@timeout))
	EXEC sp_executesql @stmt,N''
	
	
	WHILE ( (@retry = 1) AND (@retrycont <= @maxretries) )
	BEGIN
		SET @retry = 0;
    
    	-- Bloque TRY
    	BEGIN TRY 
    		
    	    		
    		--Obteniendo informacion de seguridad y auditoria--
			EXEC dbo.spzaProcesoUsuario_Consultar @id_usuario   = @id_usuario       ,
												  @id_proceso   = @idproce 		    , 
												  @bl_permit    = @bl_permit OUTPUT , 
												  @bl_auditsuc  = @bl_as 	 OUTPUT , 
												  @bl_auditfail = @bl_af 	 OUTPUT ;
			
			IF (@bl_permit = 0)
			BEGIN 
				
				SELECT 'No posee permisos suficientes para ejecutar esta acciÃ³n.' AS 'Respuesta'
				RETURN @retval;
			END 
			
	   

	   			--inicio dzuniga 2016/05/16  LLEVAR LOS EMD A UNA MISMA NACIONALIDAD 
			DECLARE @TAerolineas Table (entidad char(3))
			DECLARE @bl_EMD AS char(1)
			DECLARE @nacionalidad_EMD AS INT
			DECLARE @cd_TipoDocEMD AS VARCHAR(3)
			DECLARE @cd_categoria AS VARCHAR(25)
			--aerolineas para cambiar la nacionalidad de las EMD
			INSERT INTO @TAerolineas
			SELECT e.cd_siglas FROM dbo.fnSplit( (SELECT  VALOR FROM Parametros WHERE id = 452 ),',',0,1) T
			INNER JOIN Entidades E ON E.cd_codigo = T.Codigo

			SET @bl_EMD = isnull ((SELECT  VALOR FROM Parametros WHERE id = 451) ,'N')
			SET @nacionalidad_EMD = CASE WHEN (SELECT  VALOR FROM Parametros WHERE id = 453 )='Nacional' THEN 1 ELSE 2 END
			SELECT @cd_TipoDocEMD=LTRIM(RTRIM(VALOR)) FROM Parametros WHERE id = 369
			--FIN dzuniga 2016/05/16



			--Instrucciones del procedimiento-----------------------------------------
				SELECT 
					@bl_BSP = 0
					, @bl_tomarvendedorcliente = 0 /*rgelis 2014/12/18 - Toma el vendedor del cliente -EVT*/
					, @bl_TomarSucursalImplantePCCGDS = 0
					, @TomarTC_Voucher_Auto_ZeusTC = 0
					, @bl_GenerarFacturaXTiquete = 0
				
				SELECT @bl_tomarvendedorcliente = CASE WHEN rtrim(ltrim(Valor))='S' THEN 1 ELSE 0 END  FROM dbo.Parametros where Id=367 /*rgelis 2014/12/18 - Toma el vendedor del cliente -EVT*/
				SELECT @bl_TomarSucursalImplantePCCGDS = CASE WHEN rtrim(ltrim(Valor))='S' THEN 1 ELSE 0 END  FROM dbo.Parametros where Id=373 
				SELECT @bl_BSP = CASE WHEN rtrim(ltrim(Valor))='S' THEN 1 ELSE 0 END  FROM dbo.Parametros where Id=327
				SELECT @TomarTC_Voucher_Auto_ZeusTC = CASE WHEN rtrim(ltrim(Valor))='S' THEN 1 ELSE 0 END  FROM dbo.Parametros where Id=408
				SELECT @bl_GenerarFacturaXTiquete = CASE WHEN rtrim(ltrim(Valor))='S' THEN 1 ELSE 0 END  FROM dbo.Parametros where Id=423 /*JARG 2015/07/25 - Generar una factura por tiquete, en la facturacion automatica -M&M*/
				SELECT @cd_categoria = rtrim(ltrim(Valor)) FROM dbo.Parametros WHERE id=387
				SELECT @bl_tomarnacionalidadDetalles = CASE WHEN rtrim(ltrim(Valor))='S' THEN 1 ELSE 0 END  FROM dbo.Parametros where Id=582
				SELECT @bl_tomartiposervicionacionalidad = CASE WHEN rtrim(ltrim(Valor))='S' THEN 1 ELSE 0 END  FROM dbo.Parametros where Id=584 
				SELECT @cd_tiposervicionacional = rtrim(ltrim(Valor)) FROM dbo.Parametros where Id=585
				SELECT @cd_tiposerviciointernacional = rtrim(ltrim(Valor)) FROM dbo.Parametros where Id=586
				SELECT @cd_TCTipoTarjetaMostrarNumero = rtrim(ltrim(Valor)) FROM dbo.Parametros where Id=573
				SELECT @bl_tomarFPAirplusTkt = CASE WHEN rtrim(ltrim(Valor))='S' THEN 1 ELSE 0 END  FROM dbo.Parametros where Id=608
				SELECT @bl_tomarFPTaoTkt = CASE WHEN rtrim(ltrim(Valor))='S' THEN 1 ELSE 0 END  FROM dbo.Parametros where Id=609
				SET @bl_tomarFPAirplusTkt=ISNULL(@bl_tomarFPAirplusTkt,0)
				SET @bl_tomarFPTaoTkt=isnull(@bl_tomarFPTaoTkt,0)

				IF ISNULL(@Cd_IMPLANTE,'') = ''
				BEGIN
					SET @CD_IMPLANTE = '0' 
				END 
	
				CREATE TABLE #TablaReservas(Id INT IDENTITY,Id_ReservasGDS INT, id_ReservaGDS_Detalles INT, ds_ItinerarioAerolinea VARCHAR(128)) 
				EXEC dbo.spza_Get_GDSFacturacionAutoJOB_ItinerarioAerolinea 
					@id_usuario		= @id_usuario,
					@cd_sucursal	= @cd_sucursal,
					@cd_implante	= @cd_implante 

					

				SELECT * FROM (
				--Tiquetes.
				SELECT PNR, Tipo, ISNULL(Servicio,'') AS 'Servicio', Descrip, id, iden_gds, ds_fecha, cd_tiqueteador, cd_vendedor, cd_cliente, am_highfare, am_lowfare, am_fare, ds_reasoncode, ISNULL(ds_cliname,'') AS 'ds_cliname', ISNULL(ds_clidir,'') AS 'ds_clidir', ISNULL(ds_clicity,'') AS 'ds_clicity', ISNULL(ds_cliid,'') AS 'ds_cliid'
						,	LEFT(CASE WHEN iden_gds = 2 then Servicio    
								WHEN isnull(rtrim(ds_itinerario),'') <> '' AND dbo.fnza_get_ReservasGDSNumeroTKts(id)>1 then ds_itinerario 
								ELSE dbo.fnza_Get_ReservaItinerarioSobrante (Id,id_air) end,63) AS 'ds_itinerario' --rgelis 2019/12/10 req.105901
						, ds_clases, in_nacionalidad, id_air, ds_pax_number, ds_pax_firstnm, ds_pax_lastnm, ds_pax_prefix, ds_tkt_number, ds_tkt_prefix, ds_aero_code, ds_moneda, am_tarifa, am_iva, ISNULL(am_tua,0) AS 'am_tua', ISNULL(am_comb,0) AS 'am_comb', CASE WHEN ISNULL(am_tua,0)>=0 AND ISNULL(am_comb,0)>=0 AND ISNULL(am_vat,0)>=0 THEN (ISNULL(am_vat,0)-(ISNULL(am_comb,0)+ISNULL(am_tua,0))) ELSE ISNULL(am_vat,0) END AS 'am_vat', ds_cc_code, ds_cc_number
						,CASE WHEN ISNULL(bl_ExentoIva,0)<>0 THEN ISNULL(am_tao,0)+ISNULL(am_ivatao,0) ELSE ISNULL(am_tao,0) END am_tao
						,CASE WHEN ISNULL(bl_ExentoIva,0)<>0 THEN 0 ELSE ISNULL(am_ivatao,0) END AS am_ivatao
						, ISNULL(am_cap,0) AS 'am_cap', ISNULL(am_ivacap,0) AS 'am_ivacap', ds_cc_code2, ds_cc_number2, am_fp1, am_fp2, cd_tktrevisado, am_TarifaContado, am_IvaContado, am_OtrosContado, am_TarifaCredito, am_IvaCredito, am_OtrosCredito, am_Comision, cd_clitipodoc, cd_clitipotercero, ds_clirazoncial, ds_cliname2, ds_clilastname, ds_clilastname2, cd_clipais, ds_clitel, cd_TipoTransaccion, ISNULL(Fecha_Salida,GETDATE()) AS 'Fecha_Salida', ISNULL(Fecha_Llegada,GETDATE()) AS 'Fecha_Llegada', Id_Srv, CASE WHEN Tipo = 'Aire' THEN in_nacionalidad WHEN Tipo='Srv' AND ISNULL(cd_conceptofacturacion,'')<>'' THEN (SELECT top 1 id FROM dbo.ConceptoFacturacion WHERE cd_codigo=cd_conceptofacturacion) ELSE cd_conceptofacturacion END AS 'cd_conceptofacturacion', cd_tiposervicio, cd_proveedores, ds_proveedores, id_car, dt_entrega, in_cars, cd_carcode, cd_conf_car, cd_citysalida, dt_retorno, cd_cartype, cd_currency, am_tarifacar, cd_bookingsource, cd_ratecode, id_htl, dt_checkin, in_guests, cd_confirmation, cd_city, cd_htlchain, dt_checkout, in_noches, ds_htlname, in_habs, cd_bed, cd_ratecode_htl, cd_htlcur, am_htltarifa, cd_agcur, am_agtarifa, ds_dir1, ds_tel, ds_fax, cd_centrocosto, NumTktConj, Respuesta, ds_solicita, cd_pax_CC, ds_lapsoviaje, ds_archivo, ds_Observaciones, ds_ClienteEmail, cd_sucursal, cd_implante, bl_ClienteActualizar, bl_NotificacionMPD, cd_FormaPagoTAO, cd_TarjetaCreditoTAO, case when LEN(ISNULL(cd_NumeroTarjetaTAO,''))>5 AND ISNULL(@cd_TCTipoTarjetaMostrarNumero,'')<>ISNULL(cd_TarjetaCreditoTAO,'') then ISNULL(RIGHT(cd_NumeroTarjetaTAO,4),'') else Isnull(cd_NumeroTarjetaTAO,'') end AS cd_NumeroTarjetaTAO , cd_VencimientoTarjetaTAO, cd_NumeroPolizaTAO, cd_AnexoPolizaTAO, am_PorDesFormaPagoTA, cd_Penalidad, ds_cc_vence, ds_cc_vence2, ds_cc_autorizacion, ds_cc_autorizacion2, ds_cc_voucher, ds_cc_voucher2, ds_AutorizacionTarjetaTAO, ds_VoucherTarjetaTAO, am_fptao, in_cc_cuotas, in_cc_cuotas2, in_cuotasTarjetaTAO, cd_TipoTarifaTAO, cd_TipoTiquete, am_TasaCambio, cd_tiqueteador_facturador, bl_ahorro, in_CantidadTarifaTAO, in_CantidadSegmentoTAO, cd_tourcode, ds_contrato, cd_PasaportePax, ds_itinerarioaerolinea, ds_tkt_prefixIata, ds_Evento, cd_iata, ds_aero_codeIata, ReservaFactura, cd_Ahorro, cd_Categoria, Id_FormasPagoAirPlus, cd_FormasPagoAirPlus, ds_FormasPagoAirPlus, cd_TarjetasCreditoAirPlus, ds_numerotarjetaAirPlus, am_PorFacParcial, am_PorFacParcial_Utilizar, in_cantpax, Id_Precompra, id_sucursal, bl_cotizacion, cd_htl, CASE WHEN ISNULL(id_FormasPago,0)=0 AND ISNULL(ds_cc_code,'')='' THEN 1 WHEN ISNULL(id_FormasPago,0)=0 AND ISNULL(ds_cc_code,'')<>'' THEN 2 ELSE id_FormasPago END AS 'id_FormasPago', CASE WHEN ISNULL(id_TarjetasCredito,0)=0 THEN (SELECT id FROM dbo.TarjetasCredito WHERE cd_codigo=ds_cc_code) ELSE id_TarjetasCredito END AS 'id_TarjetasCredito'
						, id_formapago_cliente, cd_formapago_cliente, ds_formapago_cliente,cd_fp_OtrosItems, cd_auxiliar, cd_tipoventa,am_iva2,cd_licitacion, ds_descripcion, id_tipoproveedor, cd_tipoproveedor, ds_tipoproveedor, cd_Consecutivo_variablesadicionales, cd_item	
				FROM (
					SELECT DISTINCT
						PNR = r.cd_codigo,
						'Aire' 			AS 'Tipo',
						r.ds_itinerario AS 'Servicio',
						'Tkt ' + tkt.ds_tkt_number + ' - ' + tkt.ds_pax_lastnm + ' ' + tkt.ds_pax_firstnm AS 'Descrip',
					
						r.id,
						r.iden_gds,	
						r.ds_fecha,
						CASE 
								WHEN Sucursales.bl_usartiqueteador = 1 AND Sucursales.id_tiqueteador IS NOT NULL THEN Tiqueteadores.cd_codigo
								WHEN Sucursales.bl_usarfacturador = 1 THEN r.cd_vendedor
								WHEN @bl_TomarSucursalImplantePCCGDS = 1 AND r.pcc_emite <> '' AND ISNULL(r.PCC,'') <> ISNULL(r.PCC_Emite,'') AND pcc_emite.id IS NULL THEN r.cd_vendedor
								ELSE r.cd_tiqueteador 
							END AS 'cd_tiqueteador',
						CASE 
								WHEN @bl_tomarvendedorcliente=1 THEN ISNULL(c.IDVENDE,'') 
								ELSE r.cd_vendedor 
							END AS 'cd_vendedor',	/*rgelis 2014/12/18 - Toma el vendedor del cliente -EVT*/
						r.cd_cliente,
						r.am_highfare,
						r.am_lowfare,
						r.am_fare,
						r.ds_reasoncode,
						ds_cliname = CASE WHEN LTRIM(RTRIM(ISNULL(r.ds_cliname,''))) = '' THEN ISNULL(c.razoncial, '') ELSE r.ds_cliname END,
						ds_clidir = CASE WHEN LTRIM(RTRIM(ISNULL(r.ds_clidir,''))) = '' THEN ISNULL(c.Direccion, '') ELSE r.ds_clidir END,
						ds_clicity = CASE WHEN LTRIM(RTRIM(ISNULL(r.ds_clicity,''))) = '' THEN ISNULL(c.ciudad, '') ELSE r.ds_clicity END,
						r.ds_cliid,
						case when r.iden_gds = 2 then r.ds_itinerario    
							 when isnull(rtrim(tkt.ds_itinerario),'') <> '' AND dbo.fnza_get_ReservasGDSNumeroTKts(r.id)>1 then tkt.ds_itinerario 
							 else dbo.fnza_Get_ReservaItinerarioSobrante (r.Id,tkt.Id) end AS 'ds_itinerario',
						r.ds_clases,
						--r.in_nacionalidad,
						in_nacionalidad= CASE WHEN @bl_tomarnacionalidadDetalles = 1 AND TKT.in_nacionalidad IS NOT NULL THEN TKT.in_nacionalidad 
											  WHEN @bl_EMD= 'S' 
													AND TKT.ds_aero_code IN  (SELECT entidad FROM @TAerolineas)
													AND ((R.iden_gds=2 AND (TKT.cd_Penalidad IS NOT NULL AND RTRIM(TKT.cd_Penalidad) <> ''))
														  OR (R.iden_gds = 1 AND TKT.cd_TipoTiquete = @cd_TipoDocEMD)
														)
											  THEN @nacionalidad_EMD
										      ELSE r.in_nacionalidad END,	
						tkt.id AS 'id_air',
						tkt.ds_pax_number,
						tkt.ds_pax_firstnm,
						tkt.ds_pax_lastnm,
						tkt.ds_pax_prefix,
						tkt.ds_tkt_number,
						tkt.ds_tkt_prefix,
						tkt.ds_aero_code,
						tkt.ds_moneda,
						tkt.am_tarifa,
						tkt.am_iva,
						tkt.am_tua,
						tkt.am_comb,
						tkt.am_vat,
						tkt.ds_cc_code AS 'ds_cc_code',
						CASE WHEN A.id IS NOT NULL THEN A.Numero ELSE tkt.ds_cc_number END AS 'ds_cc_number',
						CASE WHEN ISNULL(CR.bl_ExentoIva,0)<>0 THEN ISNULL(tkt.am_tao,0)+ISNULL(tkt.am_ivatao,0) ELSE ISNULL(tkt.am_tao,0) END am_tao,
						CASE WHEN ISNULL(CR.bl_ExentoIva,0)<>0 THEN 0 ELSE ISNULL(tkt.am_ivatao,0) END AS am_ivatao,
						tkt.am_cap,
						tkt.am_ivacap,
						tkt.ds_cc_code2,
						tkt.ds_cc_number2,
						tkt.am_fp1,
						tkt.am_fp2,
						RTRIM(tkt.cd_tktrevisado) AS 'cd_tktrevisado',
					
						tkt.am_TarifaContado,
						tkt.am_IvaContado,
						tkt.am_OtrosContado,
						tkt.am_TarifaCredito,
						tkt.am_IvaCredito,
						tkt.am_OtrosCredito,
						tkt.am_Comision ,
					
								
						cd_clitipodoc, 
						cd_clitipotercero, 
						ds_clirazoncial, 
						ds_cliname2, 
						ds_clilastname, 
						ds_clilastname2, 
						cd_clipais, 
						ds_clitel = CASE WHEN LTRIM(RTRIM(ISNULL(ds_clitel,''))) = '' THEN ISNULL(c.telefono, '') ELSE ds_clitel END,
						cd_TipoTransaccion = CASE WHEN @bl_BSP=1 OR r.cd_TipoTransaccion IN ('A','B') THEN '1' ELSE r.cd_TipoTransaccion END,
						Fecha_Salida = dbo.fnza_ReservaGdsHora (r.id,LEFT(r.ds_itinerario,3),1,0),
						Fecha_Llegada =dbo.fnza_ReservaGdsHora (r.id,LEFT(r.ds_itinerario,3),0,1),

						NULL AS 'Id_Srv',
						NULL AS cd_conceptofacturacion,
						NULL AS cd_tiposervicio,
						NULL AS cd_proveedores,
						NULL AS ds_proveedores,

						NULL AS 'id_car',
						NULL AS dt_entrega,
						NULL AS in_cars,
						NULL AS cd_carcode,
						NULL AS cd_conf_car,
						NULL AS cd_citysalida,
						NULL AS dt_retorno,
						NULL AS cd_cartype,
						NULL AS cd_currency,
						NULL AS am_tarifacar,
						NULL AS cd_bookingsource,
						NULL AS cd_ratecode,
					
						NULL AS 'id_htl',
						NULL AS dt_checkin,
						NULL AS in_guests,
						NULL AS cd_confirmation,
						NULL AS cd_city,
						NULL AS cd_htlchain,
						NULL AS dt_checkout,
						NULL AS in_noches,
						NULL AS ds_htlname,
						NULL AS in_habs,
						NULL AS cd_bed,
						NULL AS cd_ratecode_htl,
						NULL AS cd_htlcur,
						NULL AS am_htltarifa,
						NULL AS cd_agcur,
						NULL AS am_agtarifa,
						NULL AS ds_dir1,
						NULL AS ds_tel,
						NULL AS ds_fax,
						CASE WHEN ISNULL(v.cd_DepartCliente,'')<>'' THEN v.cd_DepartCliente ELSE r.cd_centrocosto END AS 'cd_centrocosto', --inicio rgelis 2016/09/15 req.33812
						CASE WHEN r.iden_gds = 1 AND tkt.NumTktConj>0 THEN tkt.NumTktConj-1 ELSE tkt.NumTktConj END AS 'NumTktConj', /*rgelis 2014/12/23 req....... numero de tiquetes en conjuncion -EVT*/
						'' 	 AS 'Respuesta',
						r.ds_solicita,
						Tkt.cd_pax_CC,
						Tkt.ds_lapsoviaje,
						FPA.ds_archivo,
						r.ds_Observaciones,	/*inicio rgelis 2014/03/28 req.15175*/
						ds_ClienteEmail = CASE WHEN LTRIM(RTRIM(ISNULL(r.ds_ClienteEmail,''))) = '' THEN ISNULL(c.email, '') ELSE r.ds_ClienteEmail END,
						r.cd_sucursal,
						r.cd_implante,
						r.bl_ClienteActualizar,
						CONVERT(INT,tkt.bl_NotificacionMPD) AS 'bl_NotificacionMPD', --rgelis correcion porque en la grilla siempre coloca verdadero
						CASE WHEN @TomarTC_Voucher_Auto_ZeusTC = 1 AND A.id IS NOT NULL AND A.ReversionTA IS NULL  THEN 'TC'
							 WHEN ISNULL(tkt.cd_FormaPagoTAO,'')<>'' THEN LTRIM(RTRIM(tkt.cd_FormaPagoTAO))
							 WHEN ISNULL(tkt.ds_cc_code,'')<>'' AND A.id IS NOT NULL AND A.ReversionTA IS NULL THEN 'TC' 
							 ELSE LTRIM(RTRIM(tkt.cd_FormaPagoTAO)) END AS 'cd_FormaPagoTAO',
						CASE WHEN A.id IS NOT NULL THEN A.CdTipoTarjeta ELSE tkt.cd_TarjetaCreditoTAO END AS 'cd_TarjetaCreditoTAO',
						CASE WHEN A.id IS NOT NULL THEN A.Numero ELSE tkt.cd_NumeroTarjetaTAO END AS 'cd_NumeroTarjetaTAO',
						tkt.cd_VencimientoTarjetaTAO,
						tkt.cd_NumeroPolizaTAO,
						tkt.cd_AnexoPolizaTAO,
						tkt.am_PorDesFormaPagoTA, /*fin rgelis 2014/03/28 req.15175*/
						ISNULL(tkt.cd_Penalidad,'') AS 'cd_Penalidad', /*rgelis 2014/07/16 req.20502*/
						ISNULL(tkt.ds_cc_vence,'') AS 'ds_cc_vence', 
						ISNULL(tkt.ds_cc_vence2,'') AS 'ds_cc_vence2',
						CASE WHEN tc.id IS NOT NULL AND RTRIM(ISNULL(tkt.ds_cc_autorizacion,''))='' THEN CONVERT(varchar(25),tkt.ds_tkt_number) --rgelis 2018/03/21 req.56941
							 WHEN @TomarTC_Voucher_Auto_ZeusTC = 1 THEN A.AutorizacionAerea 
							 WHEN ISNULL(A.AutorizacionAerea,'')<>'' THEN A.AutorizacionAerea 
							 ELSE RTRIM(ISNULL(tkt.ds_cc_autorizacion,'')) END AS 'ds_cc_autorizacion', 
						ISNULL(tkt.ds_cc_autorizacion2,'') AS 'ds_cc_autorizacion2',
						CASE WHEN tc.id IS NOT NULL AND RTRIM(ISNULL(tkt.ds_cc_voucher,''))='' THEN LEFT(tkt.ds_tkt_number,10) ELSE CASE WHEN @TomarTC_Voucher_Auto_ZeusTC = 1 THEN CONVERT(VARCHAR(10),A.VoucherAerolinea) ELSE CASE WHEN ISNULL(A.VoucherAerolinea,'') ='' then RTRIM(ISNULL(tkt.ds_cc_voucher,'')) ELSE convert(varchar,A.VoucherAerolinea) END END END AS 'ds_cc_voucher', --rgelis 2018/03/21 req.56941				
					
						ISNULL(tkt.ds_cc_voucher2,'') AS 'ds_cc_voucher2',
					
						CASE WHEN @TomarTC_Voucher_Auto_ZeusTC = 1 THEN convert(varchar,A.AutorizacionTA) ELSE CASE WHEN ISNULL(A.AutorizacionTA,'') ='' then LTRIM(RTRIM(ISNULL(tkt.ds_AutorizacionTarjetaTAO,''))) else convert(varchar,A.AutorizacionTA) END END AS 'ds_AutorizacionTarjetaTAO',
						CASE WHEN @TomarTC_Voucher_Auto_ZeusTC = 1 THEN convert(varchar,A.VoucherTA) ELSE CASE WHEN ISNULL(A.VoucherTA,'') ='' then LTRIM(RTRIM(ISNULL(tkt.ds_VoucherTarjetaTAO,''))) else convert(varchar,A.VoucherTA) END END AS 'ds_VoucherTarjetaTAO',

						ISNULL(tkt.am_fptao,0) AS 'am_fptao',
						CASE WHEN @TomarTC_Voucher_Auto_ZeusTC = 1 THEN A.NumeroCuotas ELSE ISNULL(A.NumeroCuotas,ISNULL(tkt.in_cc_cuotas,0)) END  AS 'in_cc_cuotas',
						ISNULL(tkt.in_cc_cuotas2,0) AS 'in_cc_cuotas2',
						CASE WHEN @TomarTC_Voucher_Auto_ZeusTC = 1 THEN A.NumeroCuotas ELSE ISNULL(A.NumeroCuotas,ISNULL(tkt.in_cuotasTarjetaTAO,0)) END AS 'in_cuotasTarjetaTAO',
						ISNULL(cd_TipoTarifaTAO,'') AS 'cd_TipoTarifaTAO',
						ISNULL(cd_TipoTiquete,'') AS 'cd_TipoTiquete',
						ISNULL(r.am_TasaCambio,0) AS 'am_TasaCambio', /*rgelis 2014/11/08 req.22124*/ 
						r.cd_vendedor as cd_tiqueteador_facturador,
						r.bl_ahorro,
						ISNULL(tkt.in_CantidadTarifaTAO,0) AS 'in_CantidadTarifaTAO',
						ISNULL(tkt.in_CantidadSegmentoTAO,0) AS 'in_CantidadSegmentoTAO',
						CASE WHEN ISNULL(r.cd_tourcode,'')<>'' THEN r.cd_tourcode ELSE ISNULL(tkt.cd_tourcode,'') END AS 'cd_tourcode',
						r.ds_contrato,
						tkt.cd_PasaportePax,
						ds_itinerarioaerolinea= CASE WHEN ISNULL(tr.ds_ItinerarioAerolinea,'') = '' THEN dbo.fnza_Get_ReservasAerolineaRutas (r.id) ELSE tr.ds_ItinerarioAerolinea END,
						ds_tkt_prefixIata,
						r.ds_Evento,
						isnull(r.cd_iata,'') AS 'cd_iata',
						TKT.ds_aero_codeIata, 
						ReservaFactura = CASE WHEN @AgruparFacturasAutomaticasXCliente = 'S' AND ISNULL(r.cd_cliente,'') <> '' THEN r.cd_cliente + '-'  + CONVERT(VARCHAR,(ROW_NUMBER()   OVER(PARTITION BY r.cd_cliente ORDER BY r.cd_cliente DESC)-1) / @MaximoNumeroTktsFacturaAutomatica)
							  ELSE r.cd_codigo + (CASE WHEN @bl_GenerarFacturaXTiquete = 1 THEN SPACE (20) + convert(VARCHAR,ROW_NUMBER()   OVER(PARTITION BY r.cd_codigo ORDER BY r.cd_codigo DESC)) ELSE '' END) END,
						r.cd_Ahorro, /*rgelis 2016/09/09 req.33775*/
						CASE WHEN ISNULL(v.cd_Categoria,'')<>'' THEN v.cd_Categoria ELSE @cd_categoria END AS 'cd_Categoria', --inicio rgelis 2016/09/15 req.33812
						Case when FPTAO.Id Is Not null Then FPTAO.id 
							 when tc.Id Is Not null And cap.id Is Not Null Then cap.Id_FormasPago 
							 Else Null End As 'Id_FormasPagoAirPlus',
						Case when FPTAO.Id Is Not null Then FPTAO.cd_codigo
							 when tc.Id Is Not null And cap.id Is Not Null Then fp.cd_codigo 
							 Else Null End As 'cd_FormasPagoAirPlus',
						Case when FPTAO.Id Is Not null Then FPTAO.ds_nombre
							 when tc.Id Is Not null And cap.id Is Not Null Then fp.ds_nombre 
							 Else Null End As 'ds_FormasPagoAirPlus',
						Case when FPTAO.Id Is Not null And tctao.id Is Not Null Then tctao.cd_codigo
							 when tc.Id Is Not null And cap.id Is Not Null Then tcap.cd_codigo 
							 Else Null End As 'cd_TarjetasCreditoAirPlus',
						Case when FPTAO.Id Is Not null And tctao.id Is Not Null Then tkt.cd_NumeroTarjetaTAO
							 when tc.Id Is Not null And cap.id Is Not Null Then ds_numerotarjeta 
							 Else Null End As 'ds_numerotarjetaAirPlus',
						tkt.am_PorFacParcial, --rgelis 2017/08/24 req.51825
						CASE WHEN tkt.am_PorFacParcial > 0 AND tkt.am_PorFacParcial<100 THEN 100-tkt.am_PorFacParcial ELSE tkt.am_PorFacParcial END AS 'am_PorFacParcial_Utilizar',-- rgelis 2017/09/14 req.51825
						tkt.in_cantpax, --rgelis 2017/08/24 req.35871
						Id_Precompra = dbo.fnza_Get_PrecompraPorTiquete (NULL,r.ds_fecha,tkt.ds_aero_code),
						id_sucursal = sp.id, --rgelis 2018/03/13 req.52081
						bl_cotizacion=0, --rgelis 2018/04/09 req.56942
						cd_htl=NULL, --rgelis 2018/04/09 req.56942
						tkt.id_FormasPago,  --rgelis 2018/11/19 req.74409
						tkt.id_TarjetasCredito, --rgelis 2018/11/19 req.74409
						id_formapago_cliente=FPC.id,  --rgelis 2019/01/24 req.75925
						cd_formapago_cliente=FPC.cd_codigo, --rgelis 2019/01/24 req.75925
						ds_formapago_cliente=FPC.ds_nombre, --rgelis 2019/01/24 req.75925
						R.cd_fp_OtrosItems,
						cd_auxiliar = '',
						r.cd_tipoventa
						,tkt.am_iva2
						,r.cd_licitacion
						,cr.bl_ExentoIva
						,ds_descripcion = ISNULL(r.ds_descripcion,'')
						,id_tipoproveedor=0
						,cd_tipoproveedor = ''
						,ds_tipoproveedor = ''
						,cd_Consecutivo_variablesadicionales=NULL
						,cd_item = ''
					FROM dbo.ReservasGDS r
					INNER JOIN dbo.ReservaGDS_Detalles tkt ON (r.id=tkt.id_reserva)
					LEFT JOIN #TablaReservas tr ON (tr.Id_ReservasGDS=tkt.id_reserva AND tr.id_ReservaGDS_Detalles=tkt.id)/* rgelis 2013/07/18 req.15537 */
					INNER JOIN (
									SELECT DISTINCT top 50  rfa.cd_sucursal,rfa.cd_implante,rfa.id_reserva,rfa.ds_Archivo 
									from dbo.ReservasGDS_FacAuto rfa 
									inner join ReservaGDS_Detalles rd on rd.id_reserva = rfa.id_reserva
									inner join dbo.ReservasGDS r on r.id = rfa.id_reserva
									LEFT JOIN CLIENTES c ON (c.IDCLIENTE = R.cd_cliente OR c.IDCLIENTE= r.ds_cliid) /*rgelis 2014/12/18 - Toma el vendedor del cliente -EVT*/
									LEFT JOIN dbo.ConfiguracionClientesFacAuto cc ON cc.cd_codigo = c.IDCLIENTE --rgelis 2018/04/13 req.58321
									where rd.bl_usada=0 and rd.bl_anulado = 0
									AND (EXISTS (SELECT 1 FROM dbo.fnSplitMejorado(@cd_sucursal, ',', 0, 1) s WHERE s.Codigo = rfa.cd_sucursal) OR ISNULL(@cd_sucursal,'')='' OR @FiltrarSucursalFactAuto = 0)
									AND (EXISTS (SELECT 1 FROM dbo.fnSplitMejorado(@cd_implante, ',', 0, 1) i WHERE i.Codigo = ISNULL(rfa.cd_implante,'0')) OR ISNULL(@cd_implante,'')='' OR @FiltrarImplanteFactAuto = 0)
									AND (cc.id IS NOT NULL OR @SoloUtilizarConfgClienteFacAuto=0)
								)fpa ON fpa.id_reserva = r.id
					LEFT JOIN CLIENTES c ON (c.IDCLIENTE = R.cd_cliente OR c.IDCLIENTE= r.ds_cliid) /*rgelis 2014/12/18 - Toma el vendedor del cliente -EVT*/
					--LEFT JOIN Configuracion_remisiones CR ON (CR.ID_CLIENTE = C.IDCLIENTE OR C.IDCLIENTE = R.ds_cliid)
					LEFT JOIN Configuracion_remisiones CR ON (CR.ID_CLIENTE = C.IDCLIENTE)
					LEFT JOIN dbo.Sucursales ON Sucursales.cd_codigo = r.cd_sucursal
					LEFT JOIN dbo.Tiqueteadores ON Tiqueteadores.id = Sucursales.id_tiqueteador
					LEFT JOIN dbo.Implantes pcc_emite ON pcc_emite.cd_codigo = r.pcc_emite
					OUTER APPLY dbo.fnza_ZeusTc_Autorizaciones(r.cd_codigo) AS A
					OUTER APPLY dbo.fnza_GetCategoriaVariableGDSTable(r.cd_codigo) AS v
					LEFT JOIN dbo.tarjetascredito tc on tc.cd_codigo = tkt.ds_cc_code AND (tc.bl_airplus = 1 OR @bl_tomarFPAirplusTkt=1)
					LEFT JOIN dbo.Cliente_FP_AirPlus cap on cap.id_cliente = c.idcliente
					LEFT JOIN dbo.FormasPago fp on fp.id = cap.Id_FormasPago
					LEFT JOIN dbo.tarjetascredito tcap on tcap.id=cap.Id_TarjetasCredito
					LEFT JOIN dbo.Sucursales SP ON (SP.cd_codigo = tkt.cd_PSeudo OR SP.cd_alterno=tkt.cd_PSeudo) --rgelis 2018/03/13 req.50281
					LEFT JOIN dbo.ConfiguracionClientesFacAuto cc ON cc.cd_codigo = c.IDCLIENTE --rgelis 2018/04/13 req.58321
					LEFT JOIN dbo.FormasPago FPC ON FPC.cd_codigo = r.cd_formapago_cliente--rgelis 2019/01/24 req.75925
					LEFT JOIN dbo.FormasPago FPTAO ON FPTAO.cd_codigo=Tkt.cd_FormaPagoTAO AND @bl_tomarFPTaoTkt=1 
					LEFT JOIN dbo.tarjetascredito tctao on tctao.cd_codigo=tkt.cd_TarjetaCreditoTAO
					WHERE tkt.bl_usada = 0
					AND tkt.bl_anulado = 0 --rgelis 2018/08/29 Ticket.34953				
					AND (bl_NoFacturarAutomaticamente = 0 OR CR.ID IS NULL)
					AND (cc.id IS NOT NULL OR @SoloUtilizarConfgClienteFacAuto=0) --rgelis 2018/04/13 req.58321
					AND @bl_factura = 1
					AND (EXISTS (SELECT 1 FROM dbo.fnSplitMejorado(@cd_sucursal, ',', 0, 1) s WHERE s.Codigo = fpa.cd_sucursal) OR ISNULL(@cd_sucursal,'')='')
					AND (EXISTS (SELECT 1 FROM dbo.fnSplitMejorado(@cd_implante, ',', 0, 1) i WHERE i.Codigo = ISNULL(fpa.cd_implante,'0')) OR ISNULL(@cd_implante,'')='' OR @cd_implante='0')
				) AS Itinerario
				INNER JOIN (Select DISTINCT 
							Id_Reserva_ReservaGDS_Itinerarios =  ReservaGDS_Itinerarios.Id_Reserva 
							From ReservasGDS
							INNER JOIN dbo.ReservaGDS_Detalles ON ReservaGDS_Detalles.id_reserva = ReservasGDS.id
							INNER JOIN ReservaGDS_Itinerarios ON ReservaGDS_Itinerarios.Id_Reserva = ReservasGDS.Id
							WHERE ReservaGDS_Detalles.bl_usada = 0 AND ReservaGDS_Detalles.bl_anulado = 0 
							) RI ON ri.Id_Reserva_ReservaGDS_Itinerarios = ID
				--				Where Id IN (Select DISTINCT Id_Reserva From ReservaGDS_Itinerarios)

				UNION ALL

				--Servicios Car.
				SELECT distinct
					rtrim(r.cd_codigo)	AS 'PNR',
					'Auto' 			AS 'Tipo',
					car.cd_cartype	AS 'Servicio',
					'Desde ' + Convert(VARCHAR(19),car.dt_entrega) + ' hasta ' + Convert(VARCHAR(19),car.dt_retorno)  AS 'Descrip',
					
					r.id,
					r.iden_gds,	
					r.ds_fecha,
					r.cd_tiqueteador,
					CASE WHEN @bl_tomarvendedorcliente=1 THEN ISNULL(c.IDVENDE,'') ELSE r.cd_vendedor END AS 'cd_vendedor',	/*rgelis 2014/12/18 - Toma el vendedor del cliente -EVT*/
					r.cd_cliente,
					r.am_highfare,
					r.am_lowfare,
					r.am_fare,
					r.ds_reasoncode,
					ds_cliname = CASE WHEN LTRIM(RTRIM(ISNULL(r.ds_cliname,''))) = '' THEN ISNULL(c.razoncial, '') ELSE r.ds_cliname END,
					ds_clidir = CASE WHEN LTRIM(RTRIM(ISNULL(r.ds_clidir,''))) = '' THEN ISNULL(c.Direccion, '') ELSE r.ds_clidir END,
					ds_clicity = CASE WHEN LTRIM(RTRIM(ISNULL(r.ds_clicity,''))) = '' THEN ISNULL(c.ciudad, '') ELSE r.ds_clicity END,
					ds_cliid = CASE WHEN ISNULL(r.ds_cliid,'')='' AND ISNULL(r.cd_cliente,'')<>'' THEN r.cd_cliente ELSE r.ds_cliid END,
					r.ds_itinerario,
					r.ds_clases,
					in_nacionalidad=CASE WHEN ISNULL(srv.in_nacionalidad,0)<>0 THEN srv.in_nacionalidad 
										 WHEN ISNULL(r.in_nacionalidad,0)=0 THEN 1 ELSE r.in_nacionalidad END,

					NULL AS 'id_air',
					srv.ds_pax_number AS ds_pax_number,
					srv.ds_pax_firstnm AS ds_pax_firstnm,
					srv.ds_pax_lastnm AS ds_pax_lastnm,
					srv.ds_pax_prefix AS ds_pax_prefix,
					NULL AS ds_tkt_number,
					NULL AS ds_tkt_prefix,
					NULL AS ds_aero_code,
					NULL AS ds_moneda,
					srv.am_tarifa AS am_tarifa,
					srv.am_iva AS am_iva,
					NULL AS am_tua,
					NULL AS am_comb,
					srv.am_vat AS am_vat,
					srv.ds_cc_code AS ds_cc_code,
					srv.ds_cc_number AS ds_cc_number,
					NULL AS am_tao,
					NULL AS am_ivatao,
					NULL AS am_cap,
					NULL AS am_ivacap,
					srv.ds_cc_code AS ds_cc_code2,
					srv.ds_cc_number2 AS ds_cc_number2,
					srv.am_fp1 AS am_fp1,
					srv.am_fp2 AS am_fp2,
					NULL AS cd_tktrevisado,
					
					srv.am_TarifaContado AS am_TarifaContado,
					srv.am_IvaContado AS am_IvaContado,
					srv.am_OtrosContado AS am_OtrosContado,
					srv.am_TarifaCredito AS am_TarifaCredito,
					srv.am_IvaCredito AS am_IvaCredito,
					srv.am_OtrosCredito AS am_OtrosCredito,
					srv.am_Comision AS am_Comision,
					
								
					cd_clitipodoc, 
					cd_clitipotercero, 
					ds_clirazoncial, 
					ds_cliname2, 
					ds_clilastname, 
					ds_clilastname2, 
					cd_clipais, 
					ds_clitel = CASE WHEN LTRIM(RTRIM(ISNULL(ds_clitel,''))) = '' THEN ISNULL(c.telefono, '') ELSE ds_clitel END,
					cd_TipoTransaccion = CASE WHEN @bl_BSP=1 OR r.cd_TipoTransaccion IN ('A','B') THEN '1' ELSE r.cd_TipoTransaccion END,
					NULL AS 'Fecha_Salida',
					NULL AS 'Fecha_Llegada',

					srv.id AS 'Id_Srv',
					NULL AS cd_conceptofacturacion,
					NULL AS cd_tiposervicio,
					ISNULL(srv.cd_proveedores,'') AS cd_proveedores,
					ISNULL(p.RAZONCIAL,'') AS ds_proveedores,

					car.id AS 'id_car',
					car.dt_entrega,
					car.in_cars,
					car.cd_carcode,
					car.cd_confirmation AS 'cd_conf_car',
					car.cd_citysalida,
					car.dt_retorno,
					car.cd_cartype,
					car.cd_currency,
					car.am_tarifa AS 'am_tarifacar',
					car.cd_bookingsource,
					car.cd_ratecode,
					
					NULL AS 'id_htl',
					NULL AS dt_checkin,
					NULL AS in_guests,
					NULL AS cd_confirmation,
					NULL AS cd_city,
					NULL AS cd_htlchain,
					NULL AS dt_checkout,
					NULL AS in_noches,
					NULL AS ds_htlname,
					NULL AS in_habs,
					NULL AS cd_bed,
					NULL AS cd_ratecode_htl,
					NULL AS cd_htlcur,
					NULL AS am_htltarifa,
					NULL AS cd_agcur,
					NULL AS am_agtarifa,
					NULL AS ds_dir1,
					NULL AS ds_tel,
					NULL AS ds_fax,
					CASE WHEN ISNULL(v.cd_DepartCliente,'')<>'' THEN v.cd_DepartCliente ELSE r.cd_centrocosto END AS 'cd_centrocosto',		
					0 as NumTktConj,
					'' 	 AS 'Respuesta',
					r.ds_solicita,
					srv.cd_paxidentificacion as 'cd_pax_CC',
					'' as 'ds_lapsoviaje',
					FPA.ds_archivo,
					r.ds_Observaciones, 
					ds_ClienteEmail = CASE WHEN LTRIM(RTRIM(ISNULL(r.ds_ClienteEmail,''))) = '' THEN ISNULL(c.email, '') ELSE r.ds_ClienteEmail END,
					r.cd_sucursal,
					r.cd_implante,
					bl_ClienteActualizar=0,
					bl_NotificacionMPD=0,
					cd_FormaPagoTAO='',
					cd_TarjetaCreditoTAO='',
					cd_NumeroTarjetaTAO='',
					cd_VencimientoTarjetaTAO='',
					cd_NumeroPolizaTAO='',
					cd_AnexoPolizaTAO='',
					am_PorDesFormaPagoTA=0, 
					cd_Penalidad='', 
					ds_cc_vence = '', 
					ds_cc_vence2 = '',
					ds_cc_autorizacion = '',
					ds_cc_autorizacion2 = '',
					ds_cc_voucher = '',
					ds_cc_voucher2 = '',
					ds_AutorizacionTarjetaTAO = '',
					ds_VoucherTarjetaTAO = '',
					am_fptao = 0,
					in_cc_cuotas = 0,
					in_cc_cuotas2 = 0,
					in_cuotasTarjetaTAO = 0,
					cd_TipoTarifaTAO = '',
					cd_TipoTiquete = '',
					ISNULL(r.am_TasaCambio,0) AS 'am_TasaCambio',  
					r.cd_vendedor as cd_tiqueteador_facturador,
					r.bl_ahorro,
					in_CantidadTarifaTAO=0,
					in_CantidadSegmentoTAO=0,
					cd_tourcode='',
					r.ds_contrato,
					cd_PasaportePax='',
					ds_itinerarioaerolinea='',
					ds_tkt_prefixIata='',
					r.ds_Evento,
					isnull(r.cd_iata,'') AS 'cd_iata',
					ds_aero_codeIata='', 
					ReservaFactura = r.cd_codigo+'-C',
					r.cd_Ahorro,
					CASE WHEN ISNULL(v.cd_Categoria,'')<>'' THEN v.cd_Categoria ELSE @cd_categoria END AS 'cd_Categoria', 
					Id_FormasPagoAirPlus=NULL,
					cd_FormasPagoAirPlus='',
					ds_FormasPagoAirPlus='',
					cd_TarjetasCreditoAirPlus='',
					ds_numerotarjetaAirPlus='',
					am_PorFacParcial=100, 
					am_PorFacParcial_Utilizar=100,
					in_cantpax = 1,
					Id_Precompra = NULL, 
					id_sucursal = NULL, 
					bl_cotizacion=1, --rgelis 2018/04/09 req.56942
					cd_htl=NULL, --rgelis 2018/04/09 req.56942
					id_FormasPago = NULL,  --rgelis 2018/11/19 req.74409
					id_TarjetasCredito = NULL, --rgelis 2018/11/19 req.74409
					id_formapago_cliente=FPC.id,  --rgelis 2019/01/24 req.75925
					cd_formapago_cliente=FPC.cd_codigo, --rgelis 2019/01/24 req.75925
					ds_formapago_cliente=FPC.ds_nombre, --rgelis 2019/01/24 req.75925
					R.cd_fp_OtrosItems,
					srv.cd_auxiliar,
					r.cd_tipoventa
					,am_iva2=0
					,r.cd_licitacion
					,ds_descripcion=ISNULL(r.ds_descripcion,'')
					,id_tipoproveedor=ISNULL(TP.id,0)
					,cd_tipoproveedor=ISNULL(srv.cd_tipoproveedor,'')
					,ds_tipoproveedor=ISNULL(srv.ds_tipoproveedor,'')
					,cd_Consecutivo_variablesadicionales=NULL
					,cd_item = ''
				FROM dbo.ReservasGDS r
				INNER JOIN dbo.ReservaGDS_Servicios srv ON r.id=srv.id_reserva 				 
				INNER JOIN dbo.ReservaGDS_CAR car ON (car.id_reserva = r.id AND car.ds_indice=srv.ds_indice)	 
				INNER JOIN (
								
								SELECT DISTINCT top 100  rfa.cd_sucursal,rfa.cd_implante,rfa.id_reserva,rfa.ds_Archivo 
								from dbo.ReservasGDS_FacAuto rfa 
								inner join dbo.ReservasGDS r on r.id = rfa.id_reserva
								INNER JOIN dbo.ReservaGDS_Servicios srv ON r.id=srv.id_reserva 				 
								INNER JOIN dbo.ReservaGDS_CAR car ON (car.id_reserva = r.id AND car.ds_indice=srv.ds_indice)	 
								LEFT JOIN CLIENTES c ON (c.IDCLIENTE = R.cd_cliente OR c.IDCLIENTE= r.ds_cliid) /*rgelis 2014/12/18 - Toma el vendedor del cliente -EVT*/
								LEFT JOIN dbo.ConfiguracionClientesFacAuto cc ON cc.cd_codigo = c.IDCLIENTE --rgelis 2018/04/13 req.58321
								INNER JOIN @TValorInterfazGDSParametro PA ON PA.id_GDS = r.iden_gds AND PA.id_sys_entidades=131 AND PA.cd_codigo_maestro = 'FacAutoSrvGDS' AND PA.ds_valor = 'SI' --rgelis 2019/10/10 req.92991
								where srv.bl_usada=0 
								AND (EXISTS (SELECT 1 FROM dbo.fnSplitMejorado(@cd_sucursal, ',', 0, 1) s WHERE s.Codigo = rfa.cd_sucursal) OR ISNULL(@cd_sucursal,'')='' OR @FiltrarSucursalFactAuto = 0)
								AND (EXISTS (SELECT 1 FROM dbo.fnSplitMejorado(@cd_implante, ',', 0, 1) i WHERE i.Codigo = ISNULL(rfa.cd_implante,'0')) OR ISNULL(@cd_implante,'')='' OR @FiltrarImplanteFactAuto = 0)
								AND (cc.id IS NOT NULL OR @SoloUtilizarConfgClienteFacAuto=0)
							)fpa ON fpa.id_reserva = r.id
				LEFT JOIN dbo.PROVEEDORES p ON p.IDPROVE = srv.cd_proveedores 
				LEFT JOIN CLIENTES c ON (c.IDCLIENTE = R.cd_cliente OR c.IDCLIENTE= r.ds_cliid) /*rgelis 2014/12/18 - Toma el vendedor del cliente -EVT*/
				LEFT JOIN dbo.ConfiguracionClientesFacAuto cc ON cc.cd_codigo = c.IDCLIENTE --rgelis 2018/04/13 req.58321
				OUTER APPLY dbo.fnza_GetCategoriaVariableGDSTable(r.cd_codigo) AS v
				LEFT JOIN dbo.FormasPago FPC ON FPC.cd_codigo = r.cd_formapago_cliente--rgelis 2019/01/24 req.75925
				INNER JOIN @TValorInterfazGDSParametro PA ON PA.id_GDS = r.iden_gds AND PA.id_sys_entidades=131 AND PA.cd_codigo_maestro = 'FacAutoSrvGDS' AND PA.ds_valor = 'SI' --rgelis 2019/10/10 req.92991
				LEFT JOIN dbo.TipoProveedores TP ON TP.cd_codigo = srv.cd_tipoproveedor
				WHERE (EXISTS (SELECT 1 FROM dbo.fnSplitMejorado(@cd_sucursal, ',', 0, 1) s WHERE s.Codigo = fpa.cd_sucursal) OR ISNULL(@cd_sucursal,'')='')
				AND (EXISTS (SELECT 1 FROM dbo.fnSplitMejorado(@cd_implante, ',', 0, 1) i WHERE i.Codigo = ISNULL(fpa.cd_implante,'0')) OR ISNULL(@cd_implante,'')='' OR @cd_implante='0') /*rgelis 2014/03/28 req.15175*/
				AND (cc.id IS NOT NULL OR @SoloUtilizarConfgClienteFacAuto=0) --rgelis 2018/04/13 req.58321				 
				AND srv.bl_usada = 0
				AND @GenerarCotizacion=1
				--AND ISNULL(dbo.fnza_Get_ValorInterfazGDSParametro(r.iden_gds, 131, 'FacAutoSrvGDS', NULL),'')='SI' --rgelis 2019/09/25 req.92991

				
				UNION ALL
				--Servicios Hotel
				SELECT distinct
					rtrim(r.cd_codigo) 	AS 'PNR',
					'Hotel' 		AS 'Tipo',
					Convert(VARCHAR(2),htl.in_noches) + ' noches - ' + Convert(VARCHAR(2),htl.in_habs) + ' Habitacion(es) '  AS 'Servicio',
					htl.ds_htlname + ' - ' + 'CheckIn: ' + convert(VARCHAR(15),htl.dt_checkin)  AS 'Descrip',
					
					r.id,
					r.iden_gds,	
					r.ds_fecha,
					r.cd_tiqueteador,
					CASE WHEN @bl_tomarvendedorcliente=1 THEN ISNULL(c.IDVENDE,'') ELSE r.cd_vendedor END AS 'cd_vendedor',	/*rgelis 2014/12/18 - Toma el vendedor del cliente -EVT*/
					r.cd_cliente,
					r.am_highfare,
					r.am_lowfare,
					r.am_fare,
					r.ds_reasoncode,
					ds_cliname = CASE WHEN LTRIM(RTRIM(ISNULL(r.ds_cliname,''))) = '' THEN ISNULL(c.razoncial, '') ELSE r.ds_cliname END,
					ds_clidir = CASE WHEN LTRIM(RTRIM(ISNULL(r.ds_clidir,''))) = '' THEN ISNULL(c.Direccion, '') ELSE r.ds_clidir END,
					ds_clicity = CASE WHEN LTRIM(RTRIM(ISNULL(r.ds_clicity,''))) = '' THEN ISNULL(c.ciudad, '') ELSE r.ds_clicity END,
					ds_cliid = CASE WHEN ISNULL(r.ds_cliid,'')='' AND ISNULL(r.cd_cliente,'')<>'' THEN r.cd_cliente ELSE r.ds_cliid END,
					r.ds_itinerario,
					r.ds_clases,
					in_nacionalidad = CASE WHEN ISNULL(srv.in_nacionalidad,0)<>0 THEN srv.in_nacionalidad 
										   WHEN ISNULL(r.in_nacionalidad,0)=0 THEN 1 ELSE r.in_nacionalidad END,

					NULL AS 'id_air',
					srv.ds_pax_number AS ds_pax_number,
					srv.ds_pax_firstnm AS ds_pax_firstnm,
					srv.ds_pax_lastnm AS ds_pax_lastnm,
					srv.ds_pax_prefix AS ds_pax_prefix,
					NULL AS ds_tkt_number,
					NULL AS ds_tkt_prefix,
					NULL AS ds_aero_code,
					NULL AS ds_moneda,
					srv.am_tarifa AS am_tarifa,
					srv.am_iva AS am_iva,
					NULL AS am_tua,
					NULL AS am_comb,
					srv.am_vat AS am_vat,
					srv.ds_cc_code AS ds_cc_code,
					srv.ds_cc_number AS ds_cc_number,
					NULL AS am_tao,
					NULL AS am_ivatao,
					NULL AS am_cap,
					NULL AS am_ivacap,
					srv.ds_cc_code2 AS ds_cc_code2,
					srv.ds_cc_number2 AS ds_cc_number2,
					srv.am_fp1 AS am_fp1,
					srv.am_fp2 AS am_fp2,
					NULL AS cd_tktrevisado,
					
					srv.am_TarifaContado AS am_TarifaContado,
					srv.am_IvaContado AS am_IvaContado,
					srv.am_OtrosContado AS am_OtrosContado,
					srv.am_TarifaCredito AS am_TarifaCredito,
					srv.am_IvaCredito AS am_IvaCredito,
					srv.am_OtrosCredito AS am_OtrosCredito,
					srv.am_Comision AS am_Comision,
					
								
					cd_clitipodoc, 
					cd_clitipotercero, 
					ds_clirazoncial, 
					ds_cliname2, 
					ds_clilastname, 
					ds_clilastname2, 
					cd_clipais, 
					ds_clitel = CASE WHEN LTRIM(RTRIM(ISNULL(ds_clitel,''))) = '' THEN ISNULL(c.telefono, '') ELSE ds_clitel END,
					r.cd_TipoTransaccion,
					NULL AS 'Fecha_Salida',
					NULL AS 'Fecha_Llegada',

					srv.id AS 'Id_Srv',
					NULL AS cd_conceptofacturacion,
					CASE WHEN ISNULL(@bl_tomartiposervicionacionalidad,0)=1 AND ISNULL(@cd_tiposervicionacional,'')<>'' AND (CASE WHEN ISNULL(srv.in_nacionalidad,0)<>0 THEN srv.in_nacionalidad WHEN ISNULL(r.in_nacionalidad,0)=0 THEN 1 ELSE r.in_nacionalidad END)=1 THEN @cd_tiposervicionacional
						 WHEN ISNULL(@bl_tomartiposervicionacionalidad,0)=1 AND ISNULL(@cd_tiposerviciointernacional,'')<>'' AND (CASE WHEN ISNULL(srv.in_nacionalidad,0)<>0 THEN srv.in_nacionalidad WHEN ISNULL(r.in_nacionalidad,0)=0 THEN 1 ELSE r.in_nacionalidad END)=2 THEN @cd_tiposerviciointernacional
						 ELSE NULL END AS cd_tiposervicio,
					CASE WHEN ISNULL(srv.cd_proveedores,'')='' THEN ISNULL(h.cd_proveedor,'') ELSE ISNULL(srv.cd_proveedores,'') END AS cd_proveedores,
					CASE WHEN ISNULL(p.RAZONCIAL,'')='' THEN ISNULL(ph.RAZONCIAL,'') ELSE ISNULL(p.RAZONCIAL,'') END AS ds_proveedores,

					NULL AS 'id_car',
					NULL AS dt_entrega,
					NULL AS in_cars,
					NULL AS cd_carcode,
					NULL AS "cd_conf_car",
					NULL AS cd_citysalida,
					NULL AS dt_retorno,
					NULL AS cd_cartype,
					NULL AS cd_currency,
					NULL AS "am_tarifacar",
					NULL AS cd_bookingsource,
					NULL AS cd_ratecode,
					
					htl.id AS "id_htl",
					htl.dt_checkin,
					htl.in_guests,
					htl.cd_confirmation,
					htl.cd_city,
					htl.cd_htlchain,
					htl.dt_checkout,
					htl.in_noches,
					htl.ds_htlname,
					htl.in_habs,
					htl.cd_bed,
					htl.cd_ratecode AS 'cd_ratecode_htl',
					htl.cd_htlcur,
					htl.am_htltarifa,
					htl.cd_agcur,
					htl.am_agtarifa,
					htl.ds_dir1,
					htl.ds_tel,
					htl.ds_fax,
					CASE WHEN ISNULL(v.cd_DepartCliente,'')<>'' THEN v.cd_DepartCliente ELSE r.cd_centrocosto END AS 'cd_centrocosto',
					0 as NumTktConj,
					'' 	 AS 'Respuesta',
					r.ds_solicita,
					srv.cd_paxidentificacion as 'cd_pax_CC',
					'' as 'ds_lapsoviaje',
					FPA.ds_archivo,
					r.ds_Observaciones, /*inicio rgelis 2014/03/28 req.15175*/
					ds_ClienteEmail = CASE WHEN LTRIM(RTRIM(ISNULL(r.ds_ClienteEmail,''))) = '' THEN ISNULL(c.email, '') ELSE r.ds_ClienteEmail END,
					r.cd_sucursal,
					r.cd_implante,
					bl_ClienteActualizar=0,
					bl_NotificacionMPD=0,
					cd_FormaPagoTAO='',
					cd_TarjetaCreditoTAO='',
					cd_NumeroTarjetaTAO='',
					cd_VencimientoTarjetaTAO='',
					cd_NumeroPolizaTAO='',
					cd_AnexoPolizaTAO='',
					am_PorDesFormaPagoTA=0, /*fin rgelis 2014/03/20 req.15175*/
					cd_Penalidad = '', /*rgelis 2014/07/16 req.20502*/
					ds_cc_vence = '', 
					ds_cc_vence2 = '',
					ds_cc_autorizacion = '',
					ds_cc_autorizacion2 = '',
					ds_cc_voucher = '',
					ds_cc_voucher2 = '',
					ds_AutorizacionTarjetaTAO = '',
					ds_VoucherTarjetaTAO = '',
					am_fptao = 0,
					in_cc_cuotas = 0,
					in_cc_cuotas2 = 0,
					in_cuotasTarjetaTAO = 0,
					cd_TipoTarifaTAO = '',
					cd_TipoTiquete = '',
					ISNULL(r.am_TasaCambio,0) AS 'am_TasaCambio', /*rgelis 2014/11/08 req.22124*/ 
					r.cd_vendedor as cd_tiqueteador_facturador,
					r.bl_ahorro,
					in_CantidadTarifaTAO=0,
					in_CantidadSegmentoTAO=0,
					cd_tourcode='',
					r.ds_contrato,
					cd_PasaportePax='',
					ds_itinerarioaerolinea='',
					ds_tkt_prefixIata='',
					r.ds_Evento,
					isnull(r.cd_iata,'') AS 'cd_iata',
					ds_aero_codeIata='', 
					ReservaFactura = r.cd_codigo+'-C',
					r.cd_Ahorro,
					CASE WHEN ISNULL(v.cd_Categoria,'')<>'' THEN v.cd_Categoria ELSE @cd_categoria END AS 'cd_Categoria', 
					Id_FormasPagoAirPlus=NULL,
					cd_FormasPagoAirPlus='',
					ds_FormasPagoAirPlus='',
					cd_TarjetasCreditoAirPlus='',
					ds_numerotarjetaAirPlus='',
					am_PorFacParcial=100, 
					am_PorFacParcial_Utilizar=100,
					in_cantpax = 1,
					Id_Precompra = NULL,
					id_sucursal = NULL, 
					bl_cotizacion=1, --rgelis 2018/04/09 req.56942
					htl.cd_htl, --rgelis 2018/04/09 req.56942
					id_FormasPago = NULL,  --rgelis 2018/11/19 req.74409
					id_TarjetasCredito = NULL, --rgelis 2018/11/19 req.74409
					id_formapago_cliente=FPC.id,  --rgelis 2019/01/24 req.75925
					cd_formapago_cliente=FPC.cd_codigo, --rgelis 2019/01/24 req.75925
					ds_formapago_cliente=FPC.ds_nombre, --rgelis 2019/01/24 req.75925
					R.cd_fp_OtrosItems,
					srv.cd_auxiliar,
					r.cd_tipoventa

					,am_iva2=0
					,r.cd_licitacion
					,ds_descripcion=ISNULL(r.ds_descripcion,'')
					,id_tipoproveedor=ISNULL(TP.id,0)
					,cd_tipoproveedor=ISNULL(srv.cd_tipoproveedor,'')
					,ds_tipoproveedor=ISNULL(srv.ds_tipoproveedor,'')
					,cd_Consecutivo_variablesadicionales=NULL
					,cd_item = ''
				FROM dbo.ReservasGDS r
				INNER JOIN dbo.ReservaGDS_Servicios srv ON srv.id_reserva = r.id 
				INNER JOIN dbo.ReservaGDS_HTL htl ON (htl.id_reserva = r.id AND htl.ds_indice=srv.ds_indice)
				INNER JOIN (
								SELECT DISTINCT top 100  rfa.cd_sucursal,rfa.cd_implante,rfa.id_reserva,rfa.ds_Archivo 
								from dbo.ReservasGDS_FacAuto rfa 
								inner join ReservaGDS_Servicios rd on rd.id_reserva = rfa.id_reserva
								inner join dbo.ReservasGDS r on r.id = rfa.id_reserva
								LEFT JOIN CLIENTES c ON (c.IDCLIENTE = R.cd_cliente OR c.IDCLIENTE= r.ds_cliid) /*rgelis 2014/12/18 - Toma el vendedor del cliente -EVT*/
								LEFT JOIN dbo.ConfiguracionClientesFacAuto cc ON cc.cd_codigo = c.IDCLIENTE --rgelis 2018/04/13 req.58321
								where rd.bl_usada=0 and rd.bl_anulado = 0
								AND (EXISTS (SELECT 1 FROM dbo.fnSplitMejorado(@cd_sucursal, ',', 0, 1) s WHERE s.Codigo = rfa.cd_sucursal) OR ISNULL(@cd_sucursal,'')='' OR @FiltrarSucursalFactAuto = 0)
								AND (EXISTS (SELECT 1 FROM dbo.fnSplitMejorado(@cd_implante, ',', 0, 1) i WHERE i.Codigo = ISNULL(rfa.cd_implante,'0')) OR ISNULL(@cd_implante,'')='' OR @FiltrarImplanteFactAuto = 0)
								AND (cc.id IS NOT NULL OR @SoloUtilizarConfgClienteFacAuto=0)
							)fpa ON fpa.id_reserva = r.id
				LEFT JOIN dbo.Hoteles h ON h.cd_codigo = htl.cd_htl 
				LEFT JOIN dbo.PROVEEDORES p ON p.IDPROVE = srv.cd_proveedores
				LEFT JOIN dbo.PROVEEDORES ph ON ph.IDPROVE = h.cd_proveedor 
				LEFT JOIN CLIENTES c ON (c.IDCLIENTE = R.cd_cliente OR c.IDCLIENTE= r.ds_cliid) /*rgelis 2014/12/18 - Toma el vendedor del cliente -EVT*/
				LEFT JOIN dbo.ConfiguracionClientesFacAuto cc ON cc.cd_codigo = c.IDCLIENTE --rgelis 2018/04/13 req.58321
				OUTER APPLY dbo.fnza_GetCategoriaVariableGDSTable(r.cd_codigo) AS v
				LEFT JOIN dbo.FormasPago FPC ON FPC.cd_codigo = r.cd_formapago_cliente--rgelis 2019/01/24 req.75925
				LEFT JOIN dbo.TipoProveedores TP ON TP.cd_codigo = srv.cd_tipoproveedor
				WHERE (EXISTS (SELECT 1 FROM dbo.fnSplitMejorado(@cd_sucursal, ',', 0, 1) s WHERE s.Codigo = fpa.cd_sucursal) OR ISNULL(@cd_sucursal,'')='')
				AND (EXISTS (SELECT 1 FROM dbo.fnSplitMejorado(@cd_implante, ',', 0, 1) i WHERE i.Codigo = ISNULL(fpa.cd_implante,'0')) OR ISNULL(@cd_implante,'')='' OR @cd_implante='0') /*rgelis 2014/03/28 req.15175*/
				AND (cc.id IS NOT NULL OR @SoloUtilizarConfgClienteFacAuto=0) --rgelis 2018/04/13 req.58321				
				AND srv.bl_usada = 0
				AND @GenerarCotizacion=1 
				AND ISNULL(dbo.fnza_Get_ValorInterfazGDSParametro(r.iden_gds, 131, 'FacAutoSrvGDS', NULL),'')='SI' --rgelis 2019/09/25 req.92991
				
				UNION ALL
				--Servicios 
				SELECT distinct
					r.cd_codigo 	AS "PNR",
					'Srv' 			AS 'Tipo',
					ISNULL(cf.ds_nombre,'')	AS 'Servicio',
					srv.ds_descrip    AS 'Descrip',
					
					r.id,
					r.iden_gds,	
					r.ds_fecha,
					CASE 
							WHEN Sucursales.bl_usartiqueteador = 1 AND Sucursales.id_tiqueteador IS NOT NULL THEN Tiqueteadores.cd_codigo
							WHEN Sucursales.bl_usarfacturador = 1 THEN r.cd_vendedor
							WHEN @bl_TomarSucursalImplantePCCGDS = 1 AND r.pcc_emite <> '' AND ISNULL(r.PCC,'') <> ISNULL(r.PCC_Emite,'') AND pcc_emite.id IS NULL THEN r.cd_vendedor
							ELSE r.cd_tiqueteador 
						END AS 'cd_tiqueteador',
					CASE WHEN @bl_tomarvendedorcliente=1 THEN ISNULL(c.IDVENDE,'') ELSE r.cd_vendedor END AS 'cd_vendedor',	/*rgelis 2014/12/18 - Toma el vendedor del cliente -EVT*/
					r.cd_cliente,
					r.am_highfare,
					r.am_lowfare,
					r.am_fare,
					r.ds_reasoncode,
					CASE WHEN LTRIM(RTRIM(ISNULL(r.ds_cliname,''))) = '' THEN ISNULL(c.razoncial, '') ELSE r.ds_cliname END AS 'ds_cliname',
					CASE WHEN LTRIM(RTRIM(ISNULL(r.ds_clidir,''))) = '' THEN ISNULL(c.Direccion, '') ELSE r.ds_clidir END AS 'ds_clidir',
					CASE WHEN LTRIM(RTRIM(ISNULL(r.ds_clicity,''))) = '' THEN ISNULL(c.ciudad, '') ELSE r.ds_clicity END AS 'ds_clicity',
					ISNULL(r.ds_cliid,'')	AS 'ds_cliid',
					r.ds_itinerario,
					r.ds_clases,
					in_nacionalidad = CASE WHEN ISNULL(srv.in_nacionalidad,0)<>0 THEN srv.in_nacionalidad 
										   WHEN ISNULL(r.in_nacionalidad,0)=0 THEN 1 ELSE r.in_nacionalidad END,
					
					NULL AS 'id_air',
					srv.ds_pax_number,
					srv.ds_pax_firstnm,
					srv.ds_pax_lastnm,
					srv.ds_pax_prefix,
					NULL AS ds_tkt_number,
					NULL AS ds_tkt_prefix,
					NULL AS ds_aero_code,
					srv.ds_moneda,
					srv.am_tarifa,
					srv.am_iva,
					NULL AS am_tua,
					NULL AS am_comb,
					srv.am_vat,
					srv.ds_cc_code,
					srv.ds_cc_number,
					NULL AS am_tao,
					NULL AS am_ivatao,
					NULL AS am_cap,
					NULL AS am_ivacap,
					srv.ds_cc_code2,
					srv.ds_cc_number2,
					srv.am_fp1,
					srv.am_fp2,
					NULL AS 'cd_tktrevisado',
					
					srv.am_TarifaContado,
					srv.am_IvaContado,
					srv.am_OtrosContado,
					srv.am_TarifaCredito,
					srv.am_IvaCredito,
					srv.am_OtrosCredito,
					srv.am_Comision, 
					
								
					cd_clitipodoc=replace(cd_clitipodoc,char(9),''), 
					cd_clitipotercero=replace(cd_clitipotercero,char(9),''), 
					ds_clirazoncial=replace(ds_clirazoncial,char(9),''), 
					ds_cliname2=replace(ds_cliname2,char(9),''), 
					ds_clilastname=replace(ds_clilastname,char(9),''), 
					ds_clilastname2=replace(ds_clilastname2,char(9),''), 
					cd_clipais, 
					ds_clitel = CASE WHEN LTRIM(RTRIM(ISNULL(ds_clitel,''))) = '' THEN ISNULL(c.telefono, '') ELSE ds_clitel END,
					cd_TipoTransaccion = CASE WHEN @bl_BSP=1 OR r.cd_TipoTransaccion IN ('A','B') THEN '1' ELSE r.cd_TipoTransaccion END,
					NULL AS 'Fecha_Salida',
					NULL AS 'Fecha_Llegada',

					srv.id AS 'Id_Srv',
					CASE WHEN ISNULL(srv.cd_conceptofacturacion,'')='' THEN (SELECT RTRIM(Valor) FROM dbo.Parametros WHERE id=496) 
					     ELSE srv.cd_conceptofacturacion END AS 'cd_conceptofacturacion',
					CASE WHEN ISNULL(@bl_tomartiposervicionacionalidad,0)=1 AND ISNULL(@cd_tiposervicionacional,'')<>'' AND (CASE WHEN ISNULL(srv.in_nacionalidad,0)<>0 THEN srv.in_nacionalidad WHEN ISNULL(r.in_nacionalidad,0)=0 THEN 1 ELSE r.in_nacionalidad END)=1 THEN @cd_tiposervicionacional
						 WHEN ISNULL(@bl_tomartiposervicionacionalidad,0)=1 AND ISNULL(@cd_tiposerviciointernacional,'')<>'' AND (CASE WHEN ISNULL(srv.in_nacionalidad,0)<>0 THEN srv.in_nacionalidad WHEN ISNULL(r.in_nacionalidad,0)=0 THEN 1 ELSE r.in_nacionalidad END)=2 THEN @cd_tiposerviciointernacional
						 WHEN ISNULL(srv.cd_tiposervicio,'')='' THEN (SELECT RTRIM(Valor) FROM dbo.Parametros WHERE id=498)
						 ELSE srv.cd_tiposervicio END AS 'cd_tiposervicio',
					srv.cd_proveedores,
					p.RAZONCIAL AS ds_proveedores,

					NULL AS 'id_car',
					NULL AS dt_entrega,
					NULL AS in_cars,
					NULL AS cd_carcode,
					NULL AS "cd_conf_car",
					NULL AS cd_citysalida,
					NULL AS dt_retorno,
					NULL AS cd_cartype,
					NULL AS cd_currency,
					NULL AS "am_tarifacar",
					NULL AS cd_bookingsource,
					NULL AS cd_ratecode,
					
					htl.id AS 'id_htl',
					CASE WHEN htl.id Is Null Then getdate() Else htl.dt_checkin END AS dt_checkin, 
					CASE WHEN htl.id Is Null Then NULL Else in_guests END AS in_guests,
					CASE WHEN htl.id Is Null Then NULL Else cd_confirmation END AS cd_confirmation, 
					CASE WHEN htl.id Is Null Then NULL Else cd_city END AS cd_city, 
					CASE WHEN htl.id Is Null Then NULL Else cd_htlchain END AS cd_htlchain, 
					CASE WHEN htl.id Is Null Then getdate() Else htl.dt_checkout END AS dt_checkout,
					CASE WHEN htl.id Is Null Then NULL Else in_noches END AS in_noches, 
					CASE WHEN htl.id Is Null Then NULL Else replace(ds_htlname,char(9),'') END AS ds_htlname, 
					CASE WHEN htl.id Is Null Then NULL Else in_habs END AS in_habs, 
					CASE WHEN htl.id Is Null Then NULL Else cd_bed END AS cd_bed, 
					cd_ratecode AS cd_ratecode_htl, 
					NULL AS cd_htlcur,
					NULL AS am_htltarifa,
					NULL AS cd_agcur,
					NULL AS am_agtarifa,
					NULL AS ds_dir1,
					NULL AS ds_tel,
					NULL AS ds_fax,
					CASE WHEN ISNULL(v.cd_DepartCliente,'')<>'' THEN v.cd_DepartCliente ELSE r.cd_centrocosto END AS 'cd_centrocosto',
					0 as NumTktConj,
					'' 	 AS 'Respuesta',
					r.ds_solicita,
					srv.cd_paxidentificacion as 'cd_pax_CC',
					'' as 'ds_lapsoviaje',
					FPA.ds_archivo,
					r.ds_Observaciones,/*inicio rgelis 2014/03/28 req.15175*/
					ds_ClienteEmail = CASE WHEN LTRIM(RTRIM(ISNULL(r.ds_ClienteEmail,''))) = '' THEN ISNULL(c.email, '') ELSE r.ds_ClienteEmail END,
					r.cd_sucursal,
					r.cd_implante,
					bl_ClienteActualizar=0,
					bl_NotificacionMPD=0,
					cd_FormaPagoTAO='',
					cd_TarjetaCreditoTAO='',
					cd_NumeroTarjetaTAO='',
					cd_VencimientoTarjetaTAO='',
					cd_NumeroPolizaTAO='',
					cd_AnexoPolizaTAO='',
					am_PorDesFormaPagoTA=0, /*fin rgelis 2014/03/20 req.15175*/
					cd_Penalidad = '', /*rgelis 2014/07/16 req.20502*/
					ds_cc_vence = '', 
					ds_cc_vence2 = '', 
					ds_cc_autorizacion = '',
					ds_cc_autorizacion2 = '',
					ds_cc_voucher = '',
					ds_cc_voucher2 = '',
					ds_AutorizacionTarjetaTAO = '',
					ds_VoucherTarjetaTAO = '',
					am_fptao = 0,
					in_cc_cuotas = 0,
					in_cc_cuotas2 = 0,
					in_cuotasTarjetaTAO = 0,
					cd_TipoTarifaTAO = '',
					cd_TipoTiquete = '',
					ISNULL(r.am_TasaCambio,0) AS 'am_TasaCambio', /*rgelis 2014/11/08 req.22124*/ 
					r.cd_vendedor as cd_tiqueteador_facturador,
					r.bl_ahorro,
					in_CantidadTarifaTAO=0,
					in_CantidadSegmentoTAO=0,
					cd_tourcode='',
					r.ds_contrato,
					cd_PasaportePax='',
					ds_itinerarioaerolinea='',
					ds_tkt_prefixIata='',
					r.ds_Evento,
					isnull(r.cd_iata,'') AS 'cd_iata',
					ds_aero_codeIata='', 
					ReservaFactura = r.cd_codigo+'-C',
					r.cd_Ahorro,
					CASE WHEN ISNULL(v.cd_Categoria,'')<>'' THEN v.cd_Categoria ELSE @cd_categoria END AS 'cd_Categoria', 
					Id_FormasPagoAirPlus=NULL,
					cd_FormasPagoAirPlus='',
					ds_FormasPagoAirPlus='',
					cd_TarjetasCreditoAirPlus='',
					ds_numerotarjetaAirPlus='',
					am_PorFacParcial=100, 
					am_PorFacParcial_Utilizar=100,
					in_cantpax = 1,
					Id_Precompra = NULL,
					id_sucursal = NULL, --rgelis 2018/03/13 req.52081
					bl_cotizacion=0, --rgelis 2018/04/09 req.56942
					htl.cd_htl, --rgelis 2018/04/09 req.56942
					id_FormasPago = NULL,  --rgelis 2018/11/19 req.74409
					id_TarjetasCredito = NULL, --rgelis 2018/11/19 req.74409
					id_formapago_cliente=FPC.id,  --rgelis 2019/01/24 req.75925
					cd_formapago_cliente=FPC.cd_codigo, --rgelis 2019/01/24 req.75925
					ds_formapago_cliente=FPC.ds_nombre, --rgelis 2019/01/24 req.75925
					R.cd_fp_OtrosItems,
					srv.cd_auxiliar,
					r.cd_tipoventa

					,am_iva2=0
					,r.cd_licitacion
					,ds_descripcion=ISNULL(r.ds_descripcion,'')
					,id_tipoproveedor=ISNULL(TP.id,0)
					,cd_tipoproveedor=ISNULL(srv.cd_tipoproveedor,'')
					,ds_tipoproveedor=ISNULL(srv.ds_tipoproveedor,'')
					,cd_Consecutivo_variablesadicionales=NULL
					,cd_item = ''
				FROM dbo.ReservasGDS r
				INNER JOIN (
								SELECT DISTINCT top 100  rfa.cd_sucursal,rfa.cd_implante,rfa.id_reserva,rfa.ds_Archivo 
								from dbo.ReservasGDS_FacAuto rfa 
								inner join ReservaGDS_Servicios rd on rd.id_reserva = rfa.id_reserva
								inner join dbo.ReservasGDS r on r.id = rfa.id_reserva
								INNER JOIN @TValorInterfazGDSParametro PA ON PA.id_GDS = r.iden_gds AND PA.id_sys_entidades=131 AND PA.cd_codigo_maestro = 'FacAutoSrvGDS' AND PA.ds_valor = 'SI' --rgelis 2019/10/10 req.92991
								LEFT JOIN CLIENTES c ON (c.IDCLIENTE = R.cd_cliente OR c.IDCLIENTE= r.ds_cliid) /*rgelis 2014/12/18 - Toma el vendedor del cliente -EVT*/
								LEFT JOIN dbo.ConfiguracionClientesFacAuto cc ON cc.cd_codigo = c.IDCLIENTE --rgelis 2018/04/13 req.58321
								where rd.bl_usada=0 and rd.bl_anulado = 0
								AND (EXISTS (SELECT 1 FROM dbo.fnSplitMejorado(@cd_sucursal, ',', 0, 1) s WHERE s.Codigo = rfa.cd_sucursal) OR ISNULL(@cd_sucursal,'')='' OR @FiltrarSucursalFactAuto = 0)
								AND (EXISTS (SELECT 1 FROM dbo.fnSplitMejorado(@cd_implante, ',', 0, 1) i WHERE i.Codigo = ISNULL(rfa.cd_implante,'0')) OR ISNULL(@cd_implante,'')='' OR @FiltrarImplanteFactAuto = 0)
								AND (cc.id IS NOT NULL OR @SoloUtilizarConfgClienteFacAuto=0)
							)fpa ON fpa.id_reserva = r.id
				INNER JOIN dbo.ReservaGDS_Servicios srv ON (r.id=srv.id_reserva)
				LEFT JOIN dbo.ReservaGDS_HTL htl ON (r.id=htl.id_reserva and (srv.id =htl.Id_ReservaGDS_Servicios OR srv.ds_indice=htl.ds_indice))
				LEFT JOIN dbo.ConceptoFacturacion cf ON cf.cd_codigo = srv.cd_conceptofacturacion
				LEFT JOIN dbo.TiposServicios ts ON ts.cd_codigo = srv.cd_tiposervicio
				LEFT JOIN dbo.PROVEEDORES p ON p.IDPROVE = srv.cd_proveedores
				LEFT JOIN CLIENTES c ON (c.IDCLIENTE = R.cd_cliente OR c.IDCLIENTE= r.ds_cliid) /*rgelis 2014/12/18 - Toma el vendedor del cliente -EVT*/
				OUTER APPLY dbo.fnza_GetCategoriaVariableGDSTable(r.cd_codigo) AS v
				LEFT JOIN dbo.Sucursales ON Sucursales.cd_codigo = r.cd_sucursal
				LEFT JOIN dbo.Tiqueteadores ON Tiqueteadores.id = Sucursales.id_tiqueteador
				LEFT JOIN dbo.Implantes pcc_emite ON pcc_emite.cd_codigo = r.pcc_emite
				LEFT JOIN dbo.FormasPago FPC ON FPC.cd_codigo = r.cd_formapago_cliente--rgelis 2019/01/24 req.75925
				INNER JOIN @TValorInterfazGDSParametro PA ON PA.id_GDS = r.iden_gds AND PA.id_sys_entidades=131 AND PA.cd_codigo_maestro = 'FacAutoSrvGDS' AND PA.ds_valor = 'SI' --rgelis 2019/10/10 req.92991
				LEFT JOIN dbo.TipoProveedores TP ON TP.cd_codigo = srv.cd_tipoproveedor
				--WHERE fpa.cd_sucursal = @cd_sucursal 
				--AND (isnull(fpa.cd_implante,'0') = @cd_implante OR @cd_implante='0') /*rgelis 2014/03/28 req.15175*/
				--WHERE ISNULL(dbo.fnza_Get_ValorInterfazGDSParametro(r.iden_gds, 131, 'FacAutoSrvGDS', NULL),'')='SI' --rgelis 2019/09/25 req.92991			
				WHERE @bl_factura = 1 AND @GenerarCotizacion=0
				
			) AS consulta
			ORDER BY PNR
			--------------------------------------------------------------------------
			
			
			--Determinando si se debe auditar el proceso exitoso
			IF (@bl_as = 1) 
			BEGIN 										
				EXEC dbo.spzaAuditoria_Insertar  @id_proceso = @idproce    ,
												 @id_usuario = @id_usuario ,
												 @cd_status  = 1           , 												 
												 @admsg      = NULL        ,
							 					 @msgparams  = @msg;
			END 			 			
			
						
			RETURN @retval;
	    END TRY 
    																																			  
    	BEGIN CATCH 
    	-- Bloque CATCH (Manejo de excepciones)
 		
 			-- Tiempo de espera alcanzado --
		    IF ERROR_NUMBER() = 1222
		    BEGIN
      			SET @msg =  'No se pudo ejecutar el proceso. Tiempo de espera agotado.';
      			SET @retval = 1
	   	        RAISERROR (@msg,16,125);
	   	       	--Se debe auditar proceso fallido
				IF (@bl_af = 1) EXEC dbo.spzaAuditoria_Insertar  @id_proceso = @idproce ,
													 			 @id_usuario = @id_usuario ,
													 			 @cd_status  = 0           , 
													 			 @admsg      = @msg	   ;				
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
								'Procedimiento: ' + 'spza_GDSFacturacionAutoJOB_Consultar'			+ CHAR(13)+ CHAR(10) + CHAR(13)+ CHAR(10) +
								'Linea: ' + isnull(CAST(ERROR_LINE() 	   AS VARCHAR(10)),''); 							
		
					RAISERROR (@msg,16,126);
					--Se debe auditar proceso fallido
					IF (@bl_af = 1) EXEC dbo.spzaAuditoria_Insertar	@id_proceso = @idproce   ,
											 			 			@id_usuario = @id_usuario ,
											 			 			@cd_status  = 0           , 
											 			 			@admsg      = @msg	  ;				
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
		IF (@bl_af = 1) EXEC dbo.spzaAuditoria_Insertar  @id_proceso = @idproce    ,
											 			 @id_usuario = @id_usuario ,
											 			 @cd_status  = 0           , 
											 			 @admsg      = @msg	   ;												 	   					   
  		RAISERROR (@msg,16,127);
  		RETURN @retval;
  	END   	
    
    RETURN @retval;
END
GO
