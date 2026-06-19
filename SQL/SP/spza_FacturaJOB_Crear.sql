IF OBJECT_ID('dbo.spza_FacturaJOB_Crear', 'P') IS NOT NULL
    DROP PROCEDURE dbo.spza_FacturaJOB_Crear;
GO
SET QUOTED_IDENTIFIER ON;
GO
CREATE PROCEDURE [dbo].[spza_FacturaJOB_Crear]
	-- Parametros del procedimiento		
	@id_usuario						INT,  
	@id_sucursal					INT, 
	@id_implante					INT, 
	@dt_fechacont					SMALLDATETIME,
	@dt_vence						SMALLDATETIME ,
	@cd_tercero_codigo				VARCHAR(25) ,
	@ds_tercero_nombre				VARCHAR(250),
	@cd_cliente_codigo				VARCHAR(25), --rgelis 2017/02/23 req.47387
	@ds_cliente_nombre				VARCHAR(250),
	@ds_cliente_dir					VARCHAR(250),
	@ds_cliente_ciudad				VARCHAR(40),
	@ds_cliente_tel					VARCHAR(50),
	@ds_cliente_dirdesp				VARCHAR(250),
	@ds_cliente_email				VARCHAR(60),
	@ds_cliente_contacto			VARCHAR(40),
	@ds_cliente_contacto_email		VARCHAR(60),
	@id_monedas_iata				INT,
	@cd_vendedor					CHAR(3),
	@id_tiqueteador					INT,
	@bn_anexo						VARBINARY = NULL ,
	@Tcambio						MONEY = 1,
	@am_tcambiousd					MONEY = 1,
	@id_tipoventa					INT,
	@ds_num_resolucion				VARCHAR(20), 
	@in_num_inicial					NUMERIC(18,0), 
	@in_num_final					NUMERIC(18,0), 
	@ds_numeracion_autorizada		VARCHAR(50),
	@dt_fecha_resolucion			SMALLDATETIME,	
	@CodigoArchivoFisico			VARCHAR(25),
	@ds_Observacion					VARCHAR(8000) ,
	@ds_Campo_libre1				varchar(500),
	@ds_Campo_libre2				varchar(500),
	@cd_fuente_Reemplaza			CHAR(2),
	@cd_serie_Reemplaza				CHAR(2),
	@cd_consecutivo_Reemplaza		CHAR(8),		
	@ds_Actividad_Economica			VARCHAR(10),
	@ds_Tarifa_ICA					VARCHAR(15),	
	@SqlStmt						NVARCHAR(max),
	@AnticiposSqlStmt				NVARCHAR(max)=NULL,
	@TotalFactura					MONEY = 0,
	@TotalCupoCreditoCliente		MONEY = 0,
	@bl_BloqueoCupoCredito			BIT = 0,
	@bl_generadaauto				BIT = 0,
	@ds_CotizacionesId				Varchar(500)= NULL,
	@Id_Cierre						INT = NULL,
	@cd_TipoFact					CHAR(2)= NULL, /*rgelis 2012/10/31 req.10779*/
	@id_fac_remisionRelacionada		INT= NULL, /*rgelis 2013/12/23*/
	@id_fac_facturaRelacionada		INT= NULL, /*rgelis 2013/12/23*/
	@ds_DescripcionFac				VARCHAR(500)=NULL, /*rgelis 2014/02/25 req.18557*/
	@bl_nocont						BIT = 0, --rgelis 2018/04/30 req.33683
	@ProductosSqlStmt				NVARCHAR(max)=NULL,
	@cd_CF_TipoComprobante			VARCHAR(15)=NULL,
	@id_Licitacion					INT   =NULL ,
	@ValorFactura					MONEY = 0	,
	@id_Especialista				INT  =NULL,
	@id_tiqueteador_Facturador		INT = NULL,
	@id_TipoFormaPagoProveedor		INT = NULL,
	@id_MedioReservacion			INT = NULL,
	@bl_refacturacion				BIT = 0,
	@bl_comisiona					BIT = 0,
	@cd_fuente_factura				VARCHAR(2)= NULL,
	@cd_serie_factura				VARCHAR(2)= NULL,
	@cd_consecutivo_factura			VARCHAR(8)= NULL,
	@id_NotasAerolinea				INT=NULL,
	@bl_interface					INT = 0,
	@id_evento						INT   =NULL ,
	@bl_NoEnviarFacElectronica		BIT = 0,
	--@bl_FacturaComision			BIT = 0, --JARG - Req.30454 2016/03/16 - Descontar comision de la CxP de la factura Original
	@bl_DescontarComisionCxP		BIT = 0,	 --JARG - Req.30454 2016/03/16 - Descontar comision de la CxP de la factura Original
	@ds_num_resolucion_Adicional	VARCHAR(20) = '',
	@id_fac_facturaRefacturacion	VARCHAR(8000) = NULL,
	@bl_refacturacion_contabilizar_saldos BIT = 0,
	@ZML_VariablesXML				VARCHAR(MAX) = NULL,--rgelis 2017/01/04 req.46086
	@bl_FormatoResumidoFactElectro	BIT= 0, --rgelis 2018/10/08 Req.63202
	@bl_ExigeAdjuntoFactElectro		BIT= 0, --rgelis 2019/07/25 req.90259
	@bl_omitir_Validar_IVA_facturacion BIT = 0,
	@ZML_AjusteIvaXML				VARCHAR(MAX) = NULL,
	@ds_RespuestaJOB				VARCHAR(MAX) = NULL OUTPUT
AS
BEGIN
	-- SET NOCOUNT ON: Previene que conjuntos de resultados extras interfieran con 
	-- expresiones SELECT
	SET NOCOUNT ON;

    -- Declaracion e inicializacion de variables
  	DECLARE @bl_permit				BIT 	, -- Permiso de ejecucion del proceso
  			@bl_as 	   				BIT	, -- Auditar exito
	 		@bl_af 					BIT	, -- Auditar fallido	 		
			@procmsg				VARCHAR(8000)	, -- Mensaje devuelto por procedimientos llamados desde este procedimiento
			@Resolucionmsg			VARCHAR(8000)	, -- Mensaje devuelto por procedimientos llamados desde este procedimiento
			@procret 				BIT 			, -- Valor de retorno de los procedimientos llamados desde este procedimiento
			@idproce				int		    	, -- Codigo de proceso
	 		@retry 					BIT			    , -- 1=Reintentar ; 0=Abortar  
	 		@retrycont				INT			    , -- Contador de reintentos
	 		@maxretries 			INT			    , -- Maximo numero de reintentos
	 		@timeout				NVARCHAR(4000)  , -- Tiempo de espera maximo por bloqueo de registros
	 		@stmt 					NVARCHAR(4000)  , -- Cadena de instrucciones T-SQL
			@msg	    			VARCHAR(8000)   , -- Mensaje retornado por el sistema
			@retval					TINYINT 		, -- Valor de retorno de este procedimiento: 0:Exito ; 1:Error(Bloque Catch)
			@cd_serieRC				CHAR(2)			, -- Recibo de caja automatico
			@cd_fuenteRC			CHAR(2)			, -- Recibo de caja automatico
			@cd_consecutivoRC		CHAR(8)			, -- Recibo de caja automatico	
			@cd_serieRCOtr			CHAR(2)			, -- Recibo de caja automatico
			@cd_fuenteRCOtr			CHAR(2)			, -- Recibo de caja automatico
			@cd_consecutivoRCOtr	CHAR(8)			, -- Recibo de caja automatico	
			@NCF					varchar(25)		,
			@FechaCaducidad 		SmallDateTime	,
			@DocumentoCont			Varchar(10)		,
			@Id_SucursalFullFilment INT				,
			@bl_usarimplanteFullFilment INT			, 
			@Id_implanteFullFilment INT				,
			@Id_SucursalResolucion INT				,
			@Id_implanteResolucion INT				,
			@FacturadorElect varchar(50)			;

	SELECT 	@idproce 			 = 93,
			@retry				 = 1,
			@retrycont			 = 0,
			@retval				 = 0;
  	
  	-- Manejo de tiempo de espera y de reintentos por bloqueo de tablas/registros  
   	SELECT @maxretries = convert(INT,Valor) FROM dbo.Parametros WHERE Id = 60 ;
	SELECT @timeout    = convert(NVARCHAR(4000),Valor) FROM dbo.Parametros WHERE Id = 50 ;		
	SET @stmt = N'SET LOCK_TIMEOUT '+ltrim(rtrim(@timeout))
	EXEC sp_executesql @stmt,N''
	
	
	WHILE ((@retry = 1) AND (@retrycont <= @maxretries) )
	BEGIN
		SET @retry = 0;
    
    	-- Bloque TRY
    	BEGIN TRY 

			IF (NOT EXISTS(SELECT id FROM Usuario WHERE Id = @id_usuario) AND ISNULL(@Id_Cierre,0)<>0)
			BEGIN
				SELECT @id_usuario=id_usuario FROM dbo.Cierres WHERE id = @Id_Cierre  
			END
    	    		
    		--Obteniendo informacion de seguridad y auditoria--
			EXEC dbo.spzaProcesoUsuario_Consultar @id_usuario   = @id_usuario       ,
												  @id_proceso   = @idproce 		    , 
												  @bl_permit    = @bl_permit OUTPUT , 
												  @bl_auditsuc  = @bl_as 	 OUTPUT , 
												  @bl_auditfail = @bl_af 	 OUTPUT ;
			IF (@bl_permit = 0)
			BEGIN 
				SET @ds_RespuestaJOB = 'No posee permisos suficientes para ejecutar esta acciÃ³n.';SET @ds_RespuestaJOB = 'No posee permisos suficientes para ejecutar esta acciÃ³n.';
				RETURN @retval;
			END 
			
			IF @id_implante = 0
				SET @id_implante = NULL;

			IF NOT EXISTS(SELECT * FROM dbo.Implantes WHERE Implantes.id = @id_implante and Implantes.id_sucursal = @id_sucursal) AND @id_implante IS NOT NULL
			BEGIN
				SET @procmsg = 'El Implante ingresado en la Factura no esta asociado a la sucursal, verifique la configuracion implante - sucursal'
				SET @ds_RespuestaJOB = @procmsg;
				SET @ds_RespuestaJOB = @procmsg;
				RETURN 1 ;
			END	
			
			IF (RTRIM(ISNULL(@cd_vendedor,'')) = '')
			BEGIN 
				SET @ds_RespuestaJOB = 'No ingreso el vendedor de la factura por favor verificar.';SET @ds_RespuestaJOB = 'No ingreso el vendedor de la factura por favor verificar.';
				RETURN @retval;
			END
					 
			--Jramirez - 20180413 - Ticket #17146
			DECLARE @in_dias_vence INT , @ds_msj_rpta VARCHAR(8000)
			--IF EXISTS(Select * From Configuracion_remisiones Where id_cliente=@cd_cliente_codigo AND bl_BloqDiaVence = 1 AND in_dias_vence>=1)
			--BEGIN 
			--	Select @in_dias_vence = in_dias_vence From Configuracion_remisiones Where id_cliente=@cd_cliente_codigo AND bl_BloqDiaVence = 1 AND in_dias_vence>=1
			--	EXEC [spza_Configuracion_remisiones_ConsultarBloqVence]
			--		@id_usuario 		=1			,
			--		@id_cliente  		 = @cd_cliente_codigo,
			--		@in_dias_vence  	= @in_dias_vence,
			--		@bl_devolverMSJ		= 1,
			--		@ds_msj_rpta		= @ds_msj_rpta OUTPUT
			--		IF @ds_msj_rpta <> ''
			--		BEGIN
			--			SET @ds_RespuestaJOB = @cd_cliente_codigo;
			--			RETURN 1 ;
			--		END 
			--END 

			--Iniciando / salvando transaccion dependiendo si ya esta iniciada o no--
		  	BEGIN TRAN;
			
			--Verificamos si tiene sucursal por Full Filment, es decir toma la inf de facturacion de otra sucursal
			SELECT @Id_SucursalFullFilment = sff.Id
			FROM dbo.Sucursales s
			INNER JOIN dbo.Sucursales sff ON sff.id = s.Id_SucursalFullFilment
			WHERE s.id = @id_sucursal and s.bl_usarsucursalFullFilment = 1

			SELECT @Id_implanteFullFilment = iff.id 
			FROM dbo.Implantes i
			INNER JOIN Implantes iff ON iff.id = i.Id_implanteFullFilment
			WHERE i.id=@id_implante 

			--Instrucciones del procedimiento-----------------------------------------
			SET @procmsg = ''  	
			SET @Resolucionmsg = ''		
			DECLARE @cd_serie CHAR(2);
			DECLARE @cd_fuente CHAR(2);
			DECLARE @cd_consecutivo CHAR(8);
			DECLARE @in_ConsecutivoUnicoDocumento INT; --jramirez - 2017/12/05 - Manejo de consecutivo unico
			DECLARE @id_ConsecutivoUnicoDocumento INT; --jramirez - 2017/12/05 - Manejo de consecutivo unico
			DECLARE @id_Contingencia INT;
			Declare @DocumentoCausacionCxP Varchar(15)  --jramirez -- Causacion CxP servicio de terceros
					
			IF @cd_fuente_factura <> '' AND @cd_serie_factura <> '' AND @cd_consecutivo_factura <> '' 
			BEGIN 
				IF EXISTS(SELECT * FROM dbo.fac_factura WHERE fac_factura.cd_fuente = @cd_fuente_factura and fac_factura.cd_serie = @cd_serie_factura AND fac_factura.cd_consecutivo = @cd_consecutivo_factura)
				BEGIN 
					SET @procmsg = 'El Numero de Factura ingresado ya se encuentra en uso'
				END 
				ELSE
				BEGIN
					SELECT @cd_fuente		= @cd_fuente_factura,
						   @cd_serie		= @cd_serie_factura,
						   @cd_consecutivo	= @cd_consecutivo_factura
				END 
			END
			ELSE 
			BEGIN
				
				IF @Id_SucursalFullFilment IS NOT NULL
				BEGIN 
					EXEC @procret = dbo.spza_IncrementaConsecutivo @id_MaeTipoTransacciones			= 2,
													   			@id_sucursal						= @Id_SucursalFullFilment,
													   			@id_implante						= NULL, 
													   			@cd_fuente							= @cd_fuente OUTPUT,
													   			@cd_serie							= @cd_serie	OUTPUT,
													   			@cd_consecutivo						= @cd_consecutivo OUTPUT,
													   			@errmsg								= @procmsg OUTPUT, 
													   			@msg								= @Resolucionmsg OUTPUT,
																@ds_num_resolucion_Adicional		= @ds_num_resolucion_Adicional,
																@in_ConsecutivoUnicoDocumento		= @in_ConsecutivoUnicoDocumento OUTPUT,
																@id_ConsecutivoUnicoDocumento		= @id_ConsecutivoUnicoDocumento OUTPUT,
																@id_Contingencia					= @id_Contingencia OUTPUT;
				END
				ELSE IF @Id_implanteFullFilment IS NOT NULL 
				BEGIN 
					EXEC @procret = dbo.spza_IncrementaConsecutivo @id_MaeTipoTransacciones = 2,
													   			@id_sucursal             = @id_sucursal    ,
													   			@id_implante             = @Id_implanteFullFilment    , 
													   			@cd_fuente               = @cd_fuente     OUTPUT ,
													   			@cd_serie				 = @cd_serie     OUTPUT ,
													   			@cd_consecutivo          = @cd_consecutivo OUTPUT ,
													   			@errmsg					 = @procmsg OUTPUT, 
													   			@msg					 = @Resolucionmsg OUTPUT,
																@ds_num_resolucion_Adicional = @ds_num_resolucion_Adicional,
																@in_ConsecutivoUnicoDocumento		=@in_ConsecutivoUnicoDocumento OUTPUT,
																@id_ConsecutivoUnicoDocumento		= @id_ConsecutivoUnicoDocumento OUTPUT,
																@id_Contingencia					= @id_Contingencia OUTPUT;
				END 
				ELSE 
				BEGIN 
					EXEC @procret = dbo.spza_IncrementaConsecutivo @id_MaeTipoTransacciones = 2,
													   			@id_sucursal             = @id_sucursal    ,
													   			@id_implante             = @id_implante    , 
													   			@cd_fuente               = @cd_fuente     OUTPUT ,
													   			@cd_serie				 = @cd_serie     OUTPUT ,
													   			@cd_consecutivo          = @cd_consecutivo OUTPUT ,
													   			@errmsg					 = @procmsg OUTPUT, 
													   			@msg					 = @Resolucionmsg OUTPUT,
																@ds_num_resolucion_Adicional = @ds_num_resolucion_Adicional,
																@in_ConsecutivoUnicoDocumento		=@in_ConsecutivoUnicoDocumento OUTPUT,
																@id_ConsecutivoUnicoDocumento		= @id_ConsecutivoUnicoDocumento OUTPUT,
																@id_Contingencia					= @id_Contingencia OUTPUT;
				END
			END 	
			IF NOT @procmsg <> ''
			AND EXISTS(SELECT * FROM dbo.fac_factura WHERE fac_factura.cd_fuente = @cd_fuente and fac_factura.cd_serie = @cd_serie AND fac_factura.cd_consecutivo = @cd_consecutivo)
			BEGIN 
				SET @procmsg = 'El Numero de Factura: ' + @cd_fuente + '-' + @cd_serie + @cd_consecutivo + ' ya se encuentra en uso'
			END 


																					   	
			IF (@procmsg <> '') -- Proceso de incremento de consecutivo fallido				
			BEGIN 
				IF @@TRANCOUNT > 0 
				BEGIN 
					ROLLBACK TRAN;	
				END 
				
				IF (@bl_af = 1) --Se debe auditar proceso fallido
				BEGIN 						
				EXEC dbo.spzaAuditoria_Insertar  @id_proceso = @idproce    ,
												 @id_usuario = @id_usuario ,
												 @cd_status  = 1           , 												 
												 @admsg      = @procmsg	   ;	 
				END 		  
				

			    IF @bl_generadaauto=1
				BEGIN
					SET @ds_RespuestaJOB = @procmsg;
				END 
				ELSE
				BEGIN
					SET @ds_RespuestaJOB = @procmsg;
				END
				
				SET @ds_RespuestaJOB = @procmsg + ' '+  ISNULL(@Resolucionmsg,'') +' SUCURSAL:' + CONVERT(VARCHAR(3),ISNULL(@id_sucursal,0))+' IMPLANTE:' + CONVERT(VARCHAR(3),ISNULL(@id_implante,0));
				RETURN 1 ;

			END 

			--Comprobante fiscal
			If  Exists(Select* from parametros where Id=232 and valor='S') 
			And 
			Not Exists(Select * from clientes where IndNCF=1 And idcliente=@cd_cliente_codigo)
			Begin
				 
				Declare @ErrorNCF		Int
				Declare @LoginUsuario	Varchar(250) /*rgelis 2016/11/29 req.34692*/
				Declare @BU				Varchar(25)
				
				Select 
					@ErrorNCF	=	0,
					@LoginUsuario	=	Isnull(Login,''),
					@BU		=	CASE 
									WHEN i.id IS NOT NULL AND Isnull(i.cd_bu,'') <> '' THEN i.cd_bu
									WHEN s.id IS NOT NULL AND Isnull(s.cd_bu,'') <> '' THEN i.cd_bu
									ELSE '' 
								END 
				From dbo.Usuario u
				Inner Join dbo.Sucursales s ON s.id = u.id_sucursal
				Left  Join dbo.Implantes i ON i.id = u.id_implante
				Where u.Id=@id_usuario
				

				/*JARG - 2014/10/10 - Req.22484
				  Esto se hace para republica dominicana por que se necesita generar el NCF dependiendo del tipo de identificacion 
				  del cliente y agencias no permite mandar varias series, entonces se pone la serie en el codigo alterno del tipo 
				  de identificacion.*/
				DECLARE @cd_serie_NCF VARCHAR(2)
				SET @cd_serie_NCF = @cd_serie
				IF EXISTS(SELECT * FROM dbo.Parametros WHERE Parametros.Id = 240 AND Parametros.Valor = 'RepÃºblica Dominicana')
				BEGIN
					SELECT @cd_serie_NCF = @cd_CF_TipoComprobante
				END 

				Exec @ErrorNCF = spCF_Configuracion
						@Op='Consecutivo',
						@Fuente=@cd_fuente,
						@Series=@Cd_serie_NCF,
						@Usuario=@LoginUsuario,
						@BU=@Bu,
						@AplicacionUsuario='Agencia Minorista SQL',
						@NoFiscal=@NCF Output,
						@FechaCaducidad = @FechaCaducidad OutPut,
						@FechaDocumento = @dt_fechacont
				

				--Parche Comprobante fiscal: NCF es igual al numero de la factura.
				If  Exists(Select* from parametros where Id=431 and valor='S') 
				BEGIN
					SET @NCF = LEFT(@NCF,7)+@CD_CONSECUTIVO

					UPDATE DC 
					SET DC.NCF=FF.NCF
					FROM CF_DOCUMENTOCONTROL DC
					INNER JOIN FAC_FACTURA FF ON FF.CD_FUENTE = DC.FUENTE AND  FF.NUMERO = DC.DOCUMENTO
					WHERE DC.FUENTE = @cd_fuente AND DC.DOCUMENTO = @cd_serie + @cd_consecutivo AND DC.NCF<>FF.NCF
				END 

				IF (@ErrorNCF <> 0 Or @@Error <> 0) -- Proceso de incremento de consecutivo fallido				
				BEGIN 
					Set @procmsg = 'Error en generaciÃ³n de NÃºmero de Comprobante Fiscal'
					IF @@TRANCOUNT > 0 
					BEGIN 
						ROLLBACK TRAN;	
					END 
					
					IF (@bl_af = 1) --Se debe auditar proceso fallido
					BEGIN 						
					EXEC dbo.spzaAuditoria_Insertar  @id_proceso = @idproce    ,
													 @id_usuario = @id_usuario ,
													 @cd_status  = 1           , 												 
													 @admsg      = @procmsg	   ;	 
					END 		  
					
					SET @ds_RespuestaJOB = @procmsg;
					SET @ds_RespuestaJOB = @procmsg;
					RETURN 1 ;
				END 
			End
			
			--	Bloqueo Cupo Credito
		 	--IF @bl_BloqueoCupoCredito = 1
		 	--BEGIN 
				--DECLARE @TotalSacCliente MONEY,@Total MONEY, @FechaTran VARCHAR(10)
				--SET @TotalSacCliente = 0
				--SELECT @FechaTran = left(replace(VALOPAR,'/',''),6) FROM Parametr WHERE parametro ='FECHACT'				
				----VALOPAR FROM Parametr WHERE parametro ='FECHACT'				
				
				--SELECT
				--	@TotalSacCliente = sum(SACTFAC)
				--FROM dbo.FACTURAS
				--WHERE IDCLIPRV = @cd_cliente_codigo
				--	AND SACTFAC <> 0
				--	--AND VENCFAC < @FechaTran
				--	AND ANOMESFAC = @FechaTran
				--	AND CLASECP ='C'
					
				--IF @TotalSacCliente = '' OR @TotalSacCliente IS NULL
				--	SET @TotalSacCliente = 0
					
				--SET @Total = @TotalSacCliente + @TotalFactura 
				
				--IF @Total > @TotalCupoCreditoCliente 
				--BEGIN
				--	IF @@TRANCOUNT > 0 
				--	BEGIN 
				--	END					
				--	SELECT 	'El Cliente excediÃ³ su Cupo CrÃ©dito.' + space(40) + CHAR(10) + CHAR(13) + 
				--		   	'Saldo: ' + convert(VARCHAR,@TotalSacCliente,1) + CHAR(10) + CHAR(13) +
				--		   	'Total CrÃ©dito Factura: ' + convert(VARCHAR,@TotalFactura,1) + CHAR(10) + CHAR(13) +
				--		   	'Cupo CrÃ©dito: ' + convert(VARCHAR,@TotalCupoCreditoCliente,1) + CHAR(10) + CHAR(13) 
				--		    'Respuesta',
				--			1 AS 'Estado' ;
				--	RETURN 1 ;
				--END 

		 	--END
/*
			--	Validando presupuesto de la licitacion
			IF @id_Licitacion <>0
		 	BEGIN 
			
				DECLARE @RestanteLicitacion MONEY , @presupuestoLicitacion MONEY
				SET	 @RestanteLicitacion = (SELECT dbo.fnza_RestanteLicitacion(@id_Licitacion))
 				SET @presupuestoLicitacion = ISNULL ((SELECT am_presupuesto FROM Licitaciones WHERE id=@id_Licitacion),0)
				IF @ValorFactura > @RestanteLicitacion 
				BEGIN
					IF @@TRANCOUNT > 0 
					BEGIN 
						ROLLBACK TRAN ;		
					END					
					SELECT 	'Ha sobrepasado el presupuesto de la licitaciÃ³n.' + space(40) + CHAR(10) + CHAR(13) + 
							'Presupuesto: ' + convert(VARCHAR,@presupuestoLicitacion,1) + CHAR(10) + CHAR(13) +
						   	'Saldo: ' + convert(VARCHAR,@RestanteLicitacion ,1) + CHAR(10) + CHAR(13) +
						   	'Total Factura: ' + convert(VARCHAR,@ValorFactura,1) + CHAR(10) + CHAR(13) +
							'Valor faltante: ' + convert(VARCHAR,(@RestanteLicitacion-@ValorFactura),1) + CHAR(10) + CHAR(13)	 
						    'Respuesta',
							1 AS 'Estado' ;
					RETURN 1 ;
				END 

		 	END
*/		
			--Datos de resolucion
			--verificamos si el implante depende de otro implante fullfilment
			IF EXISTS(SELECT * FROM dbo.Implantes 
						WHERE id=@id_implante AND bl_usarimplanteFullFilment = 1 AND Id_implanteFullFilment IS NOT NULL)
			BEGIN
				IF EXISTS(	
							SELECT * FROM dbo.Implantes i
							INNER JOIN Implantes iff ON iff.id = i.Id_implanteFullFilment
							WHERE i.id=@id_implante 
								And iff.ds_num_resolucion is not null
								And iff.in_num_inicial <> 0
								And iff.in_num_final <> 0
								And iff.ds_numeracion_autorizada is not null
						) 	
				BEGIN
					SELECT
						@ds_num_resolucion =iff.ds_num_resolucion,
						@dt_fecha_resolucion=iff.dt_fecha_resolucion,
						@in_num_inicial=iff.in_num_inicial,
						@in_num_final =iff.in_num_final,
						@ds_numeracion_autorizada =iff.ds_numeracion_autorizada,
						@Id_SucursalResolucion = i.id_sucursal,
						@Id_implanteResolucion = i.id	
					FROM dbo.Implantes i
					INNER JOIN Implantes iff ON iff.id = i.Id_implanteFullFilment
					WHERE i.id=@id_implante 									
				END 	
				ELSE
				BEGIN 
					SELECT
						@ds_num_resolucion =ds_num_resolucion,
						@dt_fecha_resolucion=dt_fecha_resolucion,
						@in_num_inicial=in_num_inicial,
						@in_num_final =in_num_final,
						@ds_numeracion_autorizada =ds_numeracion_autorizada,
						@Id_SucursalResolucion = id,
						@Id_implanteResolucion = NULL
					FROM Sucursales WHERE id = @id_sucursal					
				END 		
			END 
			--Implante y sucursales normales
			ELSE IF EXISTS(SELECT * FROM dbo.Implantes 
						WHERE id=@id_implante 
						      And ds_num_resolucion is not null
						      And in_num_inicial <> 0
						      And in_num_final <> 0
						      And ds_numeracion_autorizada is not null
						      ) 
			BEGIN
				SELECT
					@ds_num_resolucion =ds_num_resolucion,
					@dt_fecha_resolucion=dt_fecha_resolucion,
					@in_num_inicial=in_num_inicial,
					@in_num_final =in_num_final,
					@ds_numeracion_autorizada =ds_numeracion_autorizada,
					@Id_SucursalResolucion = id_sucursal,
					@Id_implanteResolucion = id
				FROM dbo.Implantes WHERE id = @id_implante
			END
			ELSE
			BEGIN
				IF @Id_SucursalFullFilment is NOT NULL 
				BEGIN 
					SELECT
						@ds_num_resolucion =ds_num_resolucion,
						@dt_fecha_resolucion=dt_fecha_resolucion,
						@in_num_inicial=in_num_inicial,
						@in_num_final =in_num_final,
						@ds_numeracion_autorizada =ds_numeracion_autorizada,
						@Id_SucursalResolucion = Id,
						@Id_implanteResolucion = NULL
					FROM Sucursales WHERE id = @Id_SucursalFullFilment
				END
				ELSE
				BEGIN
					SELECT
						@ds_num_resolucion =ds_num_resolucion,
						@dt_fecha_resolucion=dt_fecha_resolucion,
						@in_num_inicial=in_num_inicial,
						@in_num_final =in_num_final,
						@ds_numeracion_autorizada =ds_numeracion_autorizada,
						@Id_SucursalResolucion = Id,
						@Id_implanteResolucion = NULL
					FROM Sucursales WHERE id = @id_sucursal
				END 
			END

			IF ISNULL(@id_Contingencia,0)<>0
			BEGIN
				IF @id_implante IS NULL
				BEGIN
					SELECT @ds_num_resolucion =R.ds_num_resolucion,
						   @dt_fecha_resolucion=R.dt_fecha_resolucion,
						   @in_num_inicial=R.in_num_inicial,
						   @in_num_final =R.in_num_final,
						   @ds_numeracion_autorizada =R.ds_numeracion_autorizada,
						   @Id_SucursalResolucion = R.id_sucursal,
						   @Id_implanteResolucion = NULL 
					FROM dbo.ConfiguracionTransacciones_Adicionales CA
					INNER JOIN dbo.resoluciones R ON (R.ds_num_resolucion=CA.ds_num_resolucion AND R.id_sucursal = CA.id_sucursal AND R.id_implante IS NULL)  
					WHERE CA.id_transaccion = 2 
	    				AND CA.id_sucursal = @id_sucursal
						AND CA.id_implante IS NULL
						AND CA.cd_fuente=@cd_fuente
						AND CA.cd_serie=@cd_serie
				END
				ELSE
				BEGIN
					SELECT @ds_num_resolucion =R.ds_num_resolucion,
						   @dt_fecha_resolucion=R.dt_fecha_resolucion,
						   @in_num_inicial=R.in_num_inicial,
						   @in_num_final =R.in_num_final,
						   @ds_numeracion_autorizada =R.ds_numeracion_autorizada,
						   @Id_SucursalResolucion = R.id_sucursal,
						   @Id_implanteResolucion = R.id_implante  
					FROM dbo.ConfiguracionTransacciones_Adicionales CA
					INNER JOIN dbo.resoluciones R ON (R.ds_num_resolucion=CA.ds_num_resolucion AND R.id_sucursal = CA.id_sucursal AND R.id_implante=CA.id_implante)  
					WHERE CA.id_transaccion = 2 
	    				AND CA.id_sucursal = @id_sucursal
						AND CA.id_implante = @id_implante
						AND CA.cd_fuente=@cd_fuente
						AND CA.cd_serie=@cd_serie
				END
			END
			--Validamos las resoluciones

			IF EXISTS
					(
						SELECT * 
						FROM dbo.resoluciones 
						WHERE resoluciones.id_sucursal = @Id_SucursalResolucion
						AND (resoluciones.id_implante = @Id_implanteResolucion or @Id_implanteResolucion is NULL)
						AND ds_num_resolucion = @ds_num_resolucion
						AND resoluciones.bl_nopermitirvencidas = 1
						AND resoluciones.dt_Fechavencimiento < GETDATE()
					)
			BEGIN
				IF @@TRANCOUNT > 0 
				BEGIN 
					ROLLBACK TRAN ;		
				END	
				
				--IF @bl_generadaauto=1
				--BEGIN				
				--	SELECT 	'La resoluciÃ³n: ' + @ds_num_resolucion + ' esta Vencida. Verficar parametrizacion en el maestro de resoluciones o los datos de resoluciÃ³n de la sucursal e implante.' AS 'Respuesta', 2 AS 'Estado' ;
				--END
				--ELSE
				--BEGIN
				--	SELECT 	'La resoluciÃ³n: ' + @ds_num_resolucion + ' esta Vencida. Verficar parametrizacion en el maestro de resoluciones o los datos de resoluciÃ³n de la sucursal e implante.' AS 'Respuesta', 1 AS 'Estado' ;
				--END
				
				SET @ds_RespuestaJOB = 'La resolucion: ' + @ds_num_resolucion + ' esta Vencida. Verficar parametrizacion en el maestro de resoluciones o los datos de resoluciÃ³n de la sucursal e implante.';
				RETURN 1 
			END 

			If @Id_Cierre = 0
				SET @Id_Cierre = NULL
			
			/*inicio rgelis 2012/10/31 req.10779*/	
			if (ISNULL(@cd_TipoFact,'')='')
			BEGIN
			    SELECT @cd_TipoFact=RTrim(LTrim(Valor)) FROM dbo.parametros where Id=237				
			END
			/*inicio rgelis 2012/10/31 req.10779*/

			If @id_fac_facturaRelacionada = 0
			BEGIN
				SET @id_fac_facturaRelacionada = NUll
			END

			If @id_fac_remisionRelacionada = 0
			BEGIN
				SET @id_fac_remisionRelacionada = NUll
			END
			
			If @id_Licitacion = 0
			BEGIN
				SET @id_Licitacion = NUll
			END

			If @id_evento = 0
			BEGIN
				SET @id_evento = NUll
			END			
			
			If @id_tiqueteador_Facturador = 0
			BEGIN
				SET @id_tiqueteador_Facturador = NUll
			END	

			If @id_TipoFormaPagoProveedor = 0
			BEGIN
				SET @id_TipoFormaPagoProveedor = NUll
			END			

			If @id_MedioReservacion = 0
			BEGIN
				SET @id_MedioReservacion = NUll
			END

			IF @id_NotasAerolinea=0
			BEGIN
				SET @id_NotasAerolinea=NULL
			END
			
			DECLARE @NewFacId INTEGER 
			
			INSERT INTO dbo.fac_factura
					(
					id_sucursal,
					id_implante,
					cd_fuente,
					cd_serie,
					cd_consecutivo,
					id_usuario,
					dt_fechacont,
					dt_vence,
					cd_tercero_codigo,
					ds_tercero_nombre,
					cd_cliente_codigo,
					ds_cliente_nombre,
					ds_cliente_dir,
					ds_cliente_ciudad,
					ds_cliente_tel,
					ds_cliente_dirdesp,
					ds_cliente_email,
					ds_cliente_contacto,
					ds_cliente_contacto_email,
					id_monedas_IATA,
					am_tcambio,
					cd_vendedor,
					id_tiqueteador,
					bn_anexo,
					ds_num_resolucion, 
					in_num_inicial, 
					in_num_final, 
					ds_numeracion_autorizada,
					dt_fecha_resolucion,
					am_tcambiousd,
					id_tipoventa,
					ds_observacion,
					ds_Campo_libre1,
					ds_Campo_libre2,
					cd_fuente_Reemplaza,
					cd_serie_Reemplaza,
					cd_consecutivo_Reemplaza,											
					ds_Actividad_Economica,
				   	ds_Tarifa_ICA,
					bl_generadaauto,
					Id_Cierre,
					NCF,
					FechaCaducidad,
					cd_TipoFact, /*rgelis 2012/10/31 req.10779*/
					id_fac_remisionRelacionada, /*rgelis 2013/12/23*/
					id_fac_facturaRelacionada, /*rgelis 2013/12/23*/
					ds_DescripcionFac,	/*rgelis 2014/02/25 req.18557*/
					bl_nocont, --rgelis 2018/02/16 req.33863
					cd_CF_TipoComprobante,
					id_Licitacion, 	/*dzuniga 2014/11/13 req.22097*/
					id_Especialista,	/*dzuniga 2014/12/17*/
					id_tiqueteador_Facturador,
					id_TipoFormaPagoProveedor,
					id_MedioReservacion	,
					bl_refacturacion,
					bl_comisiona,
					id_NotasAerolinea,
					bl_interface,
					id_evento,
					bl_NoEnviarFacElectronica,
					bl_DescontarComisionCxP,
					ds_num_resolucion_Adicional,
					bl_refacturacion_contabilizar_saldos,
					in_ConsecutivoUnicoDocumento,
					id_ConsecutivoUnicoDocumento,
					id_Contingencia,
					bl_FormatoResumidoFactElectro, --rgelis 2018/10/08 Req.63202
					bl_ExigeAdjuntoFactElectro --rgelis 2019/07/25 req.90259
					)
				VALUES 
					(
					@id_sucursal,
					@id_implante,
					@cd_fuente,
					@cd_serie,
					@cd_consecutivo,
					@id_usuario,
					@dt_fechacont,
					@dt_vence,
					@cd_tercero_codigo,
					@ds_tercero_nombre,
					@cd_cliente_codigo,
					@ds_cliente_nombre,
					@ds_cliente_dir,
					@ds_cliente_ciudad,
					@ds_cliente_tel,
					@ds_cliente_dirdesp,
					@ds_cliente_email,
					@ds_cliente_contacto,
					@ds_cliente_contacto_email,
					@id_monedas_iata,
					@Tcambio,
					@cd_vendedor,
					@id_tiqueteador,
					@bn_anexo,
					@ds_num_resolucion, 
					@in_num_inicial, 
					@in_num_final, 
					@ds_numeracion_autorizada,
					@dt_fecha_resolucion,
					@am_tcambiousd,
					@id_tipoventa,
					@ds_Observacion,
					@ds_Campo_libre1,
					@ds_Campo_libre2,
					@cd_fuente_Reemplaza,
					@cd_serie_Reemplaza,
					@cd_consecutivo_Reemplaza,											
					@ds_Actividad_Economica,
				  	@ds_Tarifa_ICA,
					@bl_generadaauto,
					@Id_Cierre,
					@NCF,
					@FechaCaducidad,
					@cd_TipoFact, /*rgelis 2012/10/31 req.10779*/
					@id_fac_remisionRelacionada , /*rgelis 2013/12/23*/
					@id_fac_facturaRelacionada, /*rgelis 2013/12/23 req.10779*/
					@ds_DescripcionFac,	/*rgelis 2014/02/25 req.18557*/
					@bl_nocont, --rgelis 2018/02/16 req.33863
					@cd_CF_TipoComprobante,
					@id_Licitacion,	/*dzuniga 2014/11/13 req.22097*/
					@id_Especialista,/*dzuniga 2014/12/17*/
					@id_tiqueteador_Facturador,
					@id_TipoFormaPagoProveedor,
					@id_MedioReservacion ,
					@bl_refacturacion,
					@bl_comisiona,
					@id_NotasAerolinea,
					@bl_interface,
					@id_evento,
					@bl_NoEnviarFacElectronica,
					@bl_DescontarComisionCxP,
					@ds_num_resolucion_Adicional,
					@bl_refacturacion_contabilizar_saldos,
					@in_ConsecutivoUnicoDocumento,
					@id_ConsecutivoUnicoDocumento,
					@id_Contingencia,
					@bl_FormatoResumidoFactElectro, --rgelis 2018/10/08 Req.63202
					@bl_ExigeAdjuntoFactElectro --rgelis 2019/07/25 req.90259
					)
			
			SET @NewFacId = scope_identity() 
						
			--Grabando Items y Formas de Pago
			--PRINT '--- INICIO DE SQLSTMT ---';
			--PRINT CAST(@SqlStmt AS NTEXT);
			--PRINT '--- FIN DE SQLSTMT ---';
			EXEC dbo.sp_executesql @SqlStmt, N'@NewFacId int, @NewRmId int, @FechaFac smalldatetime, @id_monedas_iata int, @Tcambio money, @id_sucursal int, @id_implante int', @NewFacId, NULL, @dt_fechacont, @id_monedas_iata, @Tcambio, @id_sucursal, @id_implante
			
			--Grabando Anticipos de Clientes
			EXEC dbo.sp_executesql @AnticiposSqlStmt, N'@NewFacId int, @NewRemId int', @NewFacId, NULL

			--Grabando Productos
			EXEC dbo.sp_executesql @ProductosSqlStmt, N'@NewFacId int, @NewRemId int', @NewFacId, NULL			
			
			Declare @ValidarProveedor  Varchar(8000)
			set @ValidarProveedor   = ''
			SELECT @ValidarProveedor = @ValidarProveedor + 'El Proveedor: "' + rtrim(Fac_servicios.cd_proveedores) + '" ingresado en el servicio: "' + rtrim(Fac_servicios.ds_servicio) + '" no existe' + char(10) + Char(13)
			FROM Fac_servicios 
			LEFT JOIN Proveedores On Proveedores.IdProve = Fac_servicios.cd_proveedores
			WHERE Id_fac_factura = @NewFacId AND ISNULL(cd_proveedores,'') <> '' AND Proveedores.IdProve IS NULL
			
			IF isnull(@ValidarProveedor,'') <> '' 
			begin
				IF @@TRANCOUNT > 0 
				BEGIN 
					ROLLBACK TRAN ;		
				END
				SET @ds_RespuestaJOB = @ValidarProveedor;
				RETURN @retval;
			end


			Declare @ValidarSrvAsociado  Varchar(8000)
			set @ValidarSrvAsociado   = ''
			SELECT @ValidarSrvAsociado = @ValidarSrvAsociado + 'El Items: "' + CASE WHEN ISNULL(fs.ds_servicio,'')<>'' THEN rtrim(fs.ds_servicio) ELSE rtrim(fs.ds_descrip) END + '" no tiene servicio asociado y el concepto de facturaciÃ³n: "' + rtrim(cf.ds_nombre) + '" lo exige' + char(10) + Char(13)
			FROM Fac_servicios fs
			INNER JOIN ConceptoFacturacion cf  On cf.id = fs.id_ConceptoFacturacion
			WHERE Id_fac_factura = @NewFacId AND ISNULL(cf.bl_ExigirServicioAsociado,0) <> 0 AND fs.id_Fac_Servicios_Depende IS NULL
			
			IF isnull(@ValidarSrvAsociado,'') <> '' 
			begin
				IF @@TRANCOUNT > 0 
				BEGIN 
					ROLLBACK TRAN ;		
				END
				SET @ds_RespuestaJOB = @ValidarSrvAsociado;
				RETURN @retval;
			end

			--inicio dzuniga 2016/08/05 Req.32444 relacionar a las facturas la nueva factura refacturada
			IF @id_fac_facturaRefacturacion IS NOT NULL
			BEGIN
				INSERT INTO fac_factura_Refacturacion
				(
					id_fac_factura ,
					Id_fac_factura_Refacturacion ,
					dt_fecha_refacturacion,
					id_usuario
				)
				SELECT 
					codigo,
					@NewFacId,
					getdate(),
					@id_usuario
				FROM DBO.fnSplit(@id_fac_facturaRefacturacion,',',0,1) t
			END
			
			--inicio dzuniga 2016/08/05 Req.32444

			--Grabamos los Id de las cotizaciones asociadas a las facturas.
			If @ds_CotizacionesId Is Not Null
			Begin
				Declare @Count Int, @MaxFile Int, @Id_Cotizacion Int
				Declare @NSrvCotz Int, @NSrvFac Int
				Declare @TotalCotizacion MONEY, @TotalSrvCotizaFac MONEY --rgelis 2017/08/11 req.51825
				Declare @TempCot Table(id Numeric Identity( 1,1) NOT NULL,  IdC Int);
				Insert Into @TempCot(IdC)
				EXEC SpSplitMejorado @ds_CotizacionesId,','
				Set @MaxFile = @@ROWCOUNT
				
				Insert Into dbo.Cotizacion_facturas (id_cotizacion, id_fac_factura)
				Select Idc,@NewFacId From @TempCot 
					
				Set @Count = 1
				While @Count <= @MaxFile
				Begin
					Select @Id_Cotizacion = IdC From @TempCot Where Id = @Count
					Select @NSrvCotz = Count(Id) From CotizacionServicios Where Id_Cotizacion = @Id_Cotizacion
					Select @NSrvFac = Count(Id) From CotizacionServicios Where Id_Cotizacion = @Id_Cotizacion and (Id_fac_Factura is not null or Id_fac_remision is not null)
					Select @TotalSrvCotizaFac=dbo.fnza_Get_CotizacionFacturaTotal(@Id_Cotizacion) --inicio rgelis 2017/08/11 req.51825
					Select @TotalCotizacion=dbo.fnza_Get_CotizacionTotal(@Id_Cotizacion)
					
					If @TotalCotizacion>@TotalSrvCotizaFac
					Begin
						Update Cotizacion Set in_estado = Case When bl_CerrarCotizacion = 1 AND bl_grupos = 1 Then 3 Else 2 End
						where Id = @Id_cotizacion
					End
					Else If @NSrvCotz <> @NSrvFac AND @NSrvCotz > 1 --fin rgelis 2017/08/11 req.51825
					Begin
						--Parcialmente Liquidada
						Update Cotizacion Set in_estado = Case When bl_CerrarCotizacion = 1 AND bl_grupos = 1 Then 3 Else 2 End --Req. 32437 - JARG
						where Id = @Id_cotizacion
					End 
					Else 
					Begin
						--Liquidada
						Update Cotizacion Set in_estado = 3
						where Id = @Id_cotizacion
					End 
					Set @Count = @Count + 1
				End				
			End
			/*inicio rgelis 2013/05/10 inserciÃ³n de comisiones al crear la factura*/
			DECLARE @Id_Factura VARCHAR(18), @EstadoInsertarComisiones Int, @MsjInsertarComisiones Varchar(8000)
			Set @EstadoInsertarComisiones = 1
			SET @Id_Factura=CONVERT(VARCHAR(18),@NewFacId)+','
			EXEC @retval=dbo.spza_Factura_InsertarComisiones 
							@id_usuario=@id_usuario
							, @id_Facturas=@Id_Factura
							, @Estado=@EstadoInsertarComisiones
							, @Msj=@MsjInsertarComisiones
							, @MostrarMsj ='N'
				
			/*fin rgelis 2013/05/10 inserciÃ³n de comisiones al crear la factura*/
						
			/*inicio rgelis 2013/06/20 validacion de las categorias de clientes*/
			DECLARE @EstadoCategorias Int, @MsjCategorias Varchar(8000)
			Set @EstadoCategorias = 1
			IF @bl_interface = 0
			BEGIN
				EXEC @retval=dbo.spza_Factura_ValidarClientes_Categorias  
								@id_usuario=@id_usuario
								, @id_fac_factura=@NewFacId
								, @Estado=@EstadoCategorias OUTPUT
								, @Msj=@MsjCategorias OUTPUT
								, @MostrarMsj ='N'
				IF @retval<>0
				BEGIN 
					IF @@TRANCOUNT > 0 
					BEGIN 
						ROLLBACK TRAN ;		
					END
					SET @ds_RespuestaJOB = @MsjCategorias;
					RETURN @retval;
				END
			END						
			/*fin rgelis 2013/06/20 validacion de las categorias de clientes*/
			
			/*inicio rgelis 2013/07/16 req.13313*/
			DECLARE @Estado Int, @Msj Varchar(8000),@id_Sys_EstadosNota INT
			Set @Estado = 1
			EXEC @retval=dbo.spza_Factura_ValidarAnticiposClientes   
							@id_usuario=@id_usuario
							, @id_fac_factura=@NewFacId
							, @Estado=@Estado OUTPUT
							, @Msj=@Msj OUTPUT
							, @MostrarMsj ='N'
			IF @retval<>0
			BEGIN 
				IF @@TRANCOUNT > 0 
				BEGIN 
					ROLLBACK TRAN ;		
				END
				SET @ds_RespuestaJOB = @Msj;
				RETURN @retval;
			END					
			/*fin rgelis 2013/07/16 req.13313*/
			SELECT @id_Sys_EstadosNota=id FROM dbo.Sys_Estados p WHERE p.id_sys_entidades = 27 AND p.bl_generacontabilizacion = 1 AND p.bl_sys = 1
			UPDATE dbo.NotasAerolinea
			SET id_fac_factura=@NewFacId
			   ,id_sys_estados=@id_Sys_EstadosNota 
			WHERE id = @id_NotasAerolinea
			
			/*Inicio - JARG - Cuando la factura tiene un solo item, validar que el tipofac de la factura sea el mismo del item*/
			If exists(Select * From dbo.Parametros Where Id = 284 And Valor = 'S')
			Begin
				SET @cd_TipoFact = '';
				
				SELECT TOP(1) @cd_TipoFact=cf.cd_TipoFact  
				FROM dbo.Fac_Factura f
					INNER JOIN dbo.Tiquetes t ON t.id_fac_factura = f.id
					INNER JOIN dbo.ConceptoFacturacion cf ON cf.id=t.in_nacionalidad
				WHERE F.Id = @NewFacId
					AND ISNULL(@cd_TipoFact,'')=''
				ORDER BY t.id DESC;

				SELECT TOP(1) @cd_TipoFact=cf.cd_TipoFact  
				FROM dbo.Fac_Factura f
					INNER JOIN dbo.fac_TAO ft ON ft.id_fac_factura = f.id
					INNER JOIN dbo.ConceptoFacturacion cf ON cf.id=ft.in_nacionalidad+3
				WHERE F.Id = @NewFacId
					AND ISNULL(@cd_TipoFact,'')=''
				ORDER BY ft.id DESC;

				SELECT TOP(1) @cd_TipoFact=cf.cd_TipoFact 
				FROM dbo.Fac_Factura f
					INNER JOIN dbo.Fac_Servicios s ON s.id_fac_factura = f.id
					INNER JOIN dbo.ConceptoFacturacion cf ON cf.id=s.id_ConceptoFacturacion
				WHERE F.Id = @NewFacId
					AND ISNULL(@cd_TipoFact,'')=''
				ORDER BY s.id DESC;

				IF (ISNULL(@cd_TipoFact,'')='' OR ISNULL(@cd_TipoFact,'')='RM')
				BEGIN
					 SELECT @cd_TipoFact = RTRIM(LTRIM(Valor)) FROM dbo.Parametros WHERE Id = 237 ;
				END

				UPDATE dbo.Fac_Factura
				Set cd_TipoFact = @cd_TipoFact
				WHERE Id = @NewFacId
			End 
			/*Fin - JARG - Cuando la factura tiene un solo item, validar que el tipofac de la factura sea el mismo del item*/
			IF @bl_generadaauto=1 --rgelis 2019/08/26 req.90259 correciones
			BEGIN
				SELECT 
					@bl_ExigeAdjuntoFactElectro = bl_ExigeAdjuntoFactElectro
				FROM dbo.Configuracion_remisiones 
				WHERE id_cliente=@cd_cliente_codigo

				IF @bl_ExigeAdjuntoFactElectro = 1
				BEGIN
					UPDATE dbo.fac_factura 
					SET bl_ExigeAdjuntoFactElectro=@bl_ExigeAdjuntoFactElectro
					WHERE id = @NewFacId
						 AND bl_ExigeAdjuntoFactElectro=0
				END
			END 
			--Facturacion Electronica
			If Exists (Select * from Parametros Where Id=306 and valor='S' AND @bl_NoEnviarFacElectronica=0 AND ISNULL(@id_Contingencia,0)=0)
			BEGIN
				if EXISTS (SELECT * FROM dbo.FUENTES WHERE IDFUENTE = @cd_fuente AND (ManejaFacturaEnLinea = 1 OR ManejaFacturaDeContingencia = 1))
				BEGIN 
					Declare @Documentra Varchar(10)
					Set @Documentra =@cd_Serie + @cd_consecutivo
					Set @Retval = 0
					Exec @Retval = SpFacturaElectronica_Peticion  
										@Categoria = 'Documentos'
										, @Operacion = 'INSERT'
										, @Llave1 = @cd_fuente
										, @Llave2 = @Documentra
										, @Llave3 = ''
										, @Llave4 = ''
										, @Fecha = @dt_fechacont	

					IF (@Retval <> 0 Or @@Error <> 0) -- Proceso fallido				
					BEGIN 
						Set @procmsg = 'Error en generaciÃ³n de FacturaciÃ³n ElectrÃ³nica'
						IF @@TRANCOUNT > 0 
						BEGIN 
							ROLLBACK TRAN;	
						END 
					
						IF (@bl_af = 1) --Se debe auditar proceso fallido
						BEGIN 						
						EXEC dbo.spzaAuditoria_Insertar  @id_proceso = @idproce    ,
															@id_usuario = @id_usuario ,
															@cd_status  = 1           , 												 
															@admsg      = @procmsg	   ;	 
						END 		  
					
						SET @ds_RespuestaJOB = @procmsg;
						RETURN 1 ;
					END 
				END 				
			End
			IF ISNULL(@id_Contingencia,0)<>0
			BEGIN
				Declare @DocumentraC Varchar(10)
				Set @DocumentraC =@cd_Serie + @cd_consecutivo
				Set @Retval = 0
				Exec @Retval = dbo.[SpContingencias]	 
						@Op				= 'RegDocContingenciaEvento'
					,	@Id				= @id_Contingencia
					,	@Codigo			= NULL
					,	@Nombre			= ''
					,	@Descripcion	= ''
					,	@Tipo			= ''
					,	@FuenteTal		= '' 
					,	@SerieTal		= ''
					,	@FechaInicio	= ''
					,	@Fechafin		= ''
					,	@Estado			= ''
					,	@Usuario		= ''
					,	@FuenteConsulta = @cd_fuente
					,	@SerieConsulta	= @cd_Serie
					,	@Documento		= @DocumentraC
					,	@ZxmlFuentes	= ''
				
				IF (@Retval <> 0 Or @@Error <> 0) -- Proceso fallido				
				BEGIN 
					Set @procmsg = 'Error en guardar de el documento de contingencia'
					IF @@TRANCOUNT > 0 
					BEGIN 
						ROLLBACK TRAN;	
					END 
					
					IF (@bl_af = 1) --Se debe auditar proceso fallido
					BEGIN 						
					EXEC dbo.spzaAuditoria_Insertar  @id_proceso = @idproce    ,
														@id_usuario = @id_usuario ,
														@cd_status  = 1           , 												 
														@admsg      = @procmsg	   ;	 
					END 		  
					
					SET @ds_RespuestaJOB = @procmsg;
					RETURN 1 ;
				END 
			END
			/*inicio rgelis 2014/12/04 req.22100*/
			IF EXISTS(SELECT * FROM dbo.Configuracion_remisiones WHERE id_cliente = @cd_cliente_codigo AND (bl_ExentoIva=1 or bl_ExentoIva2=1)) AND @bl_interface = 0
			BEGIN
				Set @Estado = 1	   
			    EXEC @retval=dbo.spza_Factura_ValidarClienteExentoIva  
							@id_usuario=@id_usuario
							, @id_fac_factura=@NewFacId
							, @Estado=@Estado OUTPUT
							, @Msj=@Msj OUTPUT
							, @MostrarMsj ='N'
				IF @retval<>0
				BEGIN 
					IF @@TRANCOUNT > 0 
					BEGIN 
						ROLLBACK TRAN ;		
					END
					SET @ds_RespuestaJOB = @Msj;
					RETURN @retval;
				END
			END
			/*fin rgelis 2014/12/04 req.22100*/

			/*inicio rgelis 2015/02/27 EVT*/
			IF EXISTS(SELECT * From dbo.Parametros WHERE Id = 399 And RTRIM(Valor) = 'S')
			BEGIN
				Set @Estado = 1	   
			    EXEC @retval=dbo.spza_Factura_ValidarTiqueteAutorizacionPagoTC  
							@id_usuario=@id_usuario
							, @id_fac_factura=@NewFacId
							, @Estado=@Estado OUTPUT
							, @Msj=@Msj OUTPUT
							, @MostrarMsj ='N'
				IF @retval<>0
				BEGIN 
					IF @@TRANCOUNT > 0 
					BEGIN 
						ROLLBACK TRAN ;		
					END
					SET @ds_RespuestaJOB = @Msj;
					RETURN @retval;
				END
			END
			/*fin rgelis 2015/02/27 EVT*/

			/*inicio rgelis 2016/04/26 req.31343*/
			IF EXISTS(SELECT * From dbo.Parametros WHERE Id = 448 And RTRIM(Valor) = 'S')
			BEGIN
				Set @Estado = 1	   
			    EXEC @retval=dbo.spza_Factura_ValidarTiqueteFormasPago  
							@id_usuario=@id_usuario
							, @id_fac_factura=@NewFacId
							, @Estado=@Estado OUTPUT
							, @Msj=@Msj OUTPUT
							, @MostrarMsj ='N'
				IF @retval<>0
				BEGIN 
					IF @@TRANCOUNT > 0 
					BEGIN 
						ROLLBACK TRAN ;		
					END
					SET @ds_RespuestaJOB = @Msj;
					RETURN @retval;
				END
			END
			/*fin rgelis 2016/04/26 req.31343*/

			/*inicio rgelis 2015/07/28 req.25394*/
			DECLARE @MsjAlerta AS VARCHAR(8000)
			IF ISNULL(@id_Licitacion,0) <> 0
			BEGIN

				Set @Estado = 1	
			    EXEC @retval=dbo.spza_Factura_AfectarLicitacion  @id_usuario=@id_usuario,@id_Licitacion=@id_Licitacion, @id_fac_factura=@NewFacId
				IF @retval<>0
				BEGIN 
					IF @@TRANCOUNT > 0 
					BEGIN 
						ROLLBACK TRAN ;		
					END
					SET @ds_RespuestaJOB = 'Error afectando la licitaciÃ³n';
					RETURN @retval;
				END
				
				Set @Estado = 1	 
			    EXEC @retval=dbo.spza_Factura_ValidarLicitacion  
							@id_usuario=@id_usuario
							, @id_fac_factura=@NewFacId
							, @Estado=@Estado OUTPUT
							, @Msj=@Msj OUTPUT
							, @MsjAlerta=@MsjAlerta OUTPUT
							, @MostrarMsj ='N'
				IF @retval<>0
				BEGIN 
					IF @@TRANCOUNT > 0 
					BEGIN 
						ROLLBACK TRAN ;		
					END
					SET @ds_RespuestaJOB = @Msj;
					RETURN @retval;
				END
			END
			/*fin rgelis 2015/07/28 req.25394*/

			/*inicio rgelis 2017/01/03 req.46086*/
			IF EXISTS(SELECT * FROM dbo.Cliente_ConfiguracionVariables CV
					  INNER JOIN dbo.VariableDefinicionMaestro VM ON (VM.IDEN=CV.IDEN_Maestro AND VM.IDEN_TipoVariable=2) 
					  WHERE CV.id_cliente = @cd_cliente_codigo 
							AND CV.bl_Exige=1
							AND VM.Codigo IN('Tiquetes','FacturacionServicios')
					 ) 
			BEGIN
				Set @Estado = 1
				EXEC @retval=dbo.spza_Factura_ValidarClientes_VariablesAdicionales  
									@id_usuario=@id_usuario
									, @id_fac_factura=@NewFacId
									, @ZML_VariablesXML=@ZML_VariablesXML
									, @Estado=@Estado OUTPUT
									, @Msj=@Msj OUTPUT
									, @MostrarMsj ='N'
				IF @retval<>0
				BEGIN 
					IF @@TRANCOUNT > 0 
					BEGIN 
						ROLLBACK TRAN ;		
					END
					SET @ds_RespuestaJOB = @Msj;
					RETURN @retval;
				END
			END							
			/*fin rgelis 2017/01/03 req.46086*/

			/*Inicio - JARG - 2015/02/25 Cola de Impresion*/
			DECLARE @bl_EnvCorreodespuesfacturar int, @bl_EnvCorreodespuesfacturarAuto INT
			SELECT @bl_EnvCorreodespuesfacturar = 0, @bl_EnvCorreodespuesfacturarAuto = 0
			
			SELECT 
				@bl_EnvCorreodespuesfacturar = bl_EnvCorreodespuesfacturar
				, @bl_EnvCorreodespuesfacturarAuto = bl_EnvCorreodespuesfacturarAuto
			FROM dbo.Configuracion_remisiones 
			WHERE id_cliente = @cd_cliente_codigo AND Configuracion_remisiones.bl_ControlarParametrosImp=1

			IF @bl_interface = 0
				AND (EXISTS (SELECT * FROM Parametros WHERE Id=395 and Valor = 'S') OR @bl_generadaauto = 1)
				AND (EXISTS (SELECT * FROM Parametros WHERE Id=394 and Valor = 'S') OR @bl_generadaauto = 0)
			BEGIN
				--24, 'Factura'
				INSERT INTO dbo.ColaImpresion_Documentos (Id_sys_entidades, id_documento )
				VALUES (24, @NewFacId)				
			END
			/*Fin - JARG - 2015/02/25 Cola de Impresion*/
			
			--Borramos de la automatica de tiquetes
			DELETE r
			FROM ReservasGDS_FacAuto R
			INNER JOIN (SELECT ReservasGDS.Id as IdReserva
			FROM dbo.fac_factura
			INNER JOIN dbo.Tiquetes on Tiquetes.id_fac_factura = fac_factura.id
			INNER JOIN dbo.ReservasGDS ON ReservasGDS.cd_codigo = Tiquetes.ds_records
			WHERE fac_factura.id = @NewFacId) AS c on c.IdReserva = R.id_reserva

			--Borramos de la automatica de servicios --inicio rgelis 2018/12/12 req.74918
			DELETE r
			FROM ReservasGDS_FacAuto R
			INNER JOIN (SELECT ReservasGDS.Id as IdReserva
			FROM dbo.fac_factura
			INNER JOIN dbo.Fac_Servicios on Fac_Servicios.id_fac_factura = fac_factura.id
			INNER JOIN dbo.ReservasGDS ON ReservasGDS.cd_codigo = Fac_Servicios.ds_records
			WHERE fac_factura.id = @NewFacId) AS c on c.IdReserva = R.id_reserva --fin rgelis 2018/12/12 req.74918
			
			/*Inicio - JARG - 2016/03/30 - R30713 - Bloqueo de Maximo (N) tkts por factura.*/		
			DECLARE @MaximoNumeroTktsFacturaManual INT
			SELECT @MaximoNumeroTktsFacturaManual = Valor FROM dbo.Parametros WHERE Id = 444
			IF @MaximoNumeroTktsFacturaManual <> 9999 --And @MaximoNumeroTktsFacturaManual <> 0
			Begin
				IF @bl_generadaauto = 0 AND (SELECT COUNT (*) FROM dbo.Tiquetes WHERE id_fac_factura = @NewFacId AND ds_itinerario IS NOT NULL AND ds_itinerario <> '') > @MaximoNumeroTktsFacturaManual
				BEGIN 
					IF @@TRANCOUNT > 0 
					BEGIN 
						ROLLBACK TRAN ;		
					END
					SELECT 
						@retval = 1, @Estado = 1
						, @Msj = 'ExcediÃ³ el mÃ¡ximo numero de tiquetes establecidos por factura. Revisar los parÃ¡metros del sistema.' 
								+ CHAR(13) + 'Parametro: ''Numero mÃ¡ximo de tiquetes en la facturaciÃ³n manual'''
				
					SET @ds_RespuestaJOB = @Msj;
					RETURN @retval;
				END 
			End
			/*Fin - JARG - 2016/03/30 - R30713 - Bloqueo de Maximo (N) tkts por factura.*/
			
			/*inicio rgelis 2017/02/21 req.47358*/
			IF EXISTS(SELECT * From dbo.Parametros WHERE Id = 479 And RTRIM(Valor) = 'S')
			BEGIN
				Set @Estado = 1	   
			    EXEC @retval=dbo.spza_Factura_ValidarTiqueteGr  
							@id_usuario=@id_usuario
							, @id_fac_factura=@NewFacId
							, @Estado=@Estado OUTPUT
							, @Msj=@Msj OUTPUT
							, @MostrarMsj ='N'
				IF @retval<>0
				BEGIN 
					IF @@TRANCOUNT > 0 
					BEGIN 
						ROLLBACK TRAN ;		
					END
					SET @ds_RespuestaJOB = @Msj;
					RETURN @retval;
				END
			END
			/*fin rgelis 2017/02/21 req.47358*/		

			/*inicio rgelis 2017/08/08 req.51825*/
			IF EXISTS(SELECT * From dbo.Parametros WHERE Id = 491 And RTRIM(Valor) = 'S')
			BEGIN
				Set @Estado = 1	   
			    EXEC @retval=dbo.spza_Factura_ValidarFacturaParcial  
							@id_usuario=@id_usuario
							, @id_fac_factura=@NewFacId
							, @Estado=@Estado OUTPUT
							, @Msj=@Msj OUTPUT
							, @MostrarMsj ='N'
				IF @retval<>0
				BEGIN 
					IF @@TRANCOUNT > 0 
					BEGIN 
						ROLLBACK TRAN ;		
					END
					SET @ds_RespuestaJOB = @Msj;
					RETURN @retval;
				END
			END
			/*fin rgelis 2017/08/08 req.51825*/

			--inicio rgelis 2018/11/22 req.74261
			Set @Estado = 1	   
			EXEC @retval=dbo.spza_Factura_ValidarConceptos  
						@id_usuario=@id_usuario
						, @id_fac_factura=@NewFacId
						, @Estado=@Estado OUTPUT
						, @Msj=@Msj OUTPUT
						, @MostrarMsj ='N'
			IF @retval<>0
			BEGIN 
				IF @@TRANCOUNT > 0 
				BEGIN 
					ROLLBACK TRAN ;		
				END
				SET @ds_RespuestaJOB = @Msj;
				RETURN @retval;
			END
			--fin rgelis 2018/11/22 req.74261

			--inicio rgelis 2019/07/30 req.90132
			IF EXISTS(SELECT * FROM dbo.Configuracion_remisiones WHERE id_cliente = @cd_cliente_codigo AND (bl_BloqCupoCrd=1 or bl_BloqDiaVence = 1 or bl_BloqManual = 1 or bl_EnvCorreoBloqDiaVence=1 or bl_EnvCorreoBloqCupoCrd=1 OR bl_AlertaAgotaCupoCrd=1)) --AND @bl_interface = 0
			BEGIN
				Set @Estado = 1	   
				EXEC @retval=dbo.spza_Factura_ValidarCupoCredito 
							@id_usuario=@id_usuario
							, @id_fac_factura=@NewFacId
							, @Estado=@Estado OUTPUT
							, @Msj=@Msj OUTPUT
							, @MsjAlerta=@MsjAlerta OUTPUT
							, @MostrarMsj ='N'
				IF @retval<>0
				BEGIN 
					IF @@TRANCOUNT > 0 
					BEGIN 
						ROLLBACK TRAN ;		
					END
					SET @ds_RespuestaJOB = @Msj;
					RETURN @retval;
				END
			END
			--fin rgelis 2019/07/30 req.90132
			
			
			Declare @TAjusteIVA TABLE 	(	am_totalBaseFac MONEY,	am_totalIVAFac MONEY,	am_totalFac MONEY,	am_totalBase_Correccion MONEY,	am_totalIVA_Correccion MONEY,	am_total_Correccion MONEY,	am_total_Diferencia MONEY,	idDocumento INT,	in_tipo INT,	id_item INT,	in_tipoitem INT,	id_cargo INT,	id_imp INT,	am_cargo MONEY,	am_imp MONEY,	am_total MONEY,	am_porcentaje MONEY,	am_impdecimal MONEY,	am_imp1 MONEY,	am_toleranciaMas1 MONEY,	am_imp2 MONEY,	am_toleranciaMenos1 MONEY	,ds_descripcion varchar(8000), am_deltaCorreccion money, am_total_Diferencia_OUT money, Documento Varchar(25))
			Declare @TAjusteIVARes TABLE 	(ds_respuesta VARCHAR(50), in_Estado INT, am_totalBaseFac MONEY,	am_totalIVAFac MONEY,	am_totalFac MONEY,	am_totalBase_Correccion MONEY,	am_totalIVA_Correccion MONEY,	am_total_Correccion MONEY,	am_total_Diferencia MONEY,	idDocumento INT,	in_tipo INT,	id_item INT,	in_tipoitem INT,	id_cargo INT,	id_imp INT,	am_cargo MONEY,	am_imp MONEY,	am_total MONEY,	am_porcentaje MONEY,	am_impdecimal MONEY,	am_imp1 MONEY,	am_toleranciaMas1 MONEY,	am_imp2 MONEY,	am_toleranciaMenos1 MONEY	,ds_descripcion varchar(8000), am_deltaCorreccion money, am_total_Diferencia_OUT money, Documento Varchar(25))
			Declare @am_total_Diferencia_OUT MONEY
			SELECT @FacturadorElect = Valor From dbo.Parametros Where Id=307
			IF (Dbo.[fnza_Get_ValorInterfazVariable](@FacturadorElect,131,'Validar_IVA_facturacion') ='SI') AND @bl_omitir_Validar_IVA_facturacion = 0 AND @bl_generadaauto = 0
			BEGIN

				INSERT INTO @TAjusteIVA 
				EXEC @retval = dbo.[spza_FacturaRemision_AjustarIVA] @id_usuario = @id_usuario, @IdDocumento = @NewFacId, @am_total_Diferencia_OUT = @am_total_Diferencia_OUT OUTPUT, @bl_vista_previa = 0, @Debug = 0,@bl_solo_validar = 1, @Tipo = 1

				Declare @Valor_tolerancia_IVA MONEY
				SELECT @Valor_tolerancia_IVA = isnull(Dbo.[fnza_Get_ValorInterfazVariable](@FacturadorElect,131,'Valor_tolerancia_IVA'),2)
				--select @Valor_tolerancia_IVA as '@Valor_tolerancia_IVA'
				IF ABS(@am_total_Diferencia_OUT) >  = ABS(ISNULL(@Valor_tolerancia_IVA,0))
				BEGIN

					IF @@TRANCOUNT > 0
					BEGIN 
						ROLLBACK TRAN ;		
					END

					SET @ds_RespuestaJOB = 'Se necesita realizar ajuste de IVA';return 1
				END
			END 
			BEGIN
				IF @bl_omitir_Validar_IVA_facturacion <>0 AND @bl_generadaauto = 0
				BEGIN
					--SET @ZML_AjusteIvaXML=REPLACE(@ZML_AjusteIvaXML,'cd_items VARCHAR(50),','')
					--SET @ZML_AjusteIvaXML=REPLACE(@ZML_AjusteIvaXML,'''''Se necesita realizar ajuste de IVA'''',2,','')
					SET @ZML_AjusteIvaXML=REPLACE(@ZML_AjusteIvaXML,'''''','''')
					INSERT INTO @TAjusteIVARes
					EXEC(@ZML_AjusteIvaXML)
					IF EXISTS(SELECT * FROM @TAjusteIVARes WHERE am_deltaCorreccion <> 0)
					BEGIN
						DELETE FROM @TAjusteIVA
						INSERT INTO @TAjusteIVA 
						EXEC @retval = dbo.[spza_FacturaRemision_AjustarIVA] @id_usuario = @id_usuario, @IdDocumento = @NewFacId, @am_total_Diferencia_OUT = @am_total_Diferencia_OUT OUTPUT, @bl_vista_previa = 1, @Debug = 0,@bl_solo_validar = 0, @Tipo = 1	
						IF @retval<>0 
						BEGIN 
   				
   							IF @@TRANCOUNT > 0 
							BEGIN 
								ROLLBACK TRAN ;		
							END
							SELECT @Estado = 1
								 , @Msj = 'Error el Ajustar los valores del iva';
							SET @ds_RespuestaJOB = @Msj;
							RETURN @retval;
						END
					END
				END	
			END

			IF NOT EXISTS(SELECT TOP 1 F.id FROM dbo.fac_factura F
						LEFT JOIN dbo.Tiquetes T ON T.id_fac_factura=F.id
						LEFT JOIN dbo.Fac_Tao FT ON FT.id_fac_factura=F.id
						LEFT JOIN dbo.Fac_Servicios FS ON FS.id_fac_factura=F.id
					  WHERE T.id IS NOT NULL OR FT.id IS NOT NULL OR FS.id IS NOT NULL
					 )
			BEGIN
				IF @@TRANCOUNT > 0 
				BEGIN 
					ROLLBACK TRAN ;		
				END

				SELECT @Estado = 1
					  , @Msj = 'Error en el crear factura no tiene item(tiquetes, tao o servicios)';
				SET @ds_RespuestaJOB = @Msj;
				RETURN 1;
			END

			--Contabilizando la Factura
			SET @retval=0 --inicio rgelis 2018/02/16 req.33683
			IF (NOT (dbo.fnza_Get_FacturaTotal(@NewFacId) = 0) AND @bl_nocont = 0) 
			BEGIN
				EXEC @retval = dbo.spza_Factura_Contabilizar @id_usuario,@NewFacId,1,@CodigoArchivoFisico
			END --fin rgelis 2018/02/16 req.33683

			IF @retval<>0 
			BEGIN 
   				
   				IF @@TRANCOUNT > 0 
				BEGIN 
					ROLLBACK TRAN ;		
				END
				
				IF (@bl_af = 1) 
				BEGIN 										
					EXEC dbo.spzaAuditoria_Insertar  @id_proceso = @idproce    ,
													 @id_usuario = @id_usuario ,
													 @cd_status  = 1           , 												 
													 @admsg      = 'Error en el proceso de contabilizacion',
								 					 @msgparams  = @msg;
				END
				RETURN @retval;
			END 
			ELSE 
			BEGIN 
				Set @DocumentoCont = @cd_serie + @cd_consecutivo
				If	Exists(Select * From Parametros Where Id = 232 and Valor = 'S')
						And 
					Not Exists(Select * from Clientes Where IndNCF = 1 And IdCliente = @cd_cliente_codigo)
				Begin
					Set @ErrorNCF = 1
					Exec @ErrorNCF = spCF_DocumentoControl   
							@Op = 'I', 
							@Fuente	= @cd_fuente, 
							@Documento = @DocumentoCont, 
							@NCF = @NCF

					IF (Isnull(@ErrorNCF, 0) <> 0 Or @@Error <> 0) --
					BEGIN 
						Set @procmsg = 'Error al actualizar Control Documentos NCF.'
						IF @@TRANCOUNT > 0 
						BEGIN 
							ROLLBACK TRAN;	
						END 
						
						IF (@bl_af = 1) --Se debe auditar proceso fallido
						BEGIN 						
						EXEC dbo.spzaAuditoria_Insertar  @id_proceso = @idproce    ,
														 @id_usuario = @id_usuario ,
														 @cd_status  = 1           , 												 
														 @admsg      = @procmsg	   ;	 
						END 		  
						
						SET @ds_RespuestaJOB = @procmsg;
						RETURN 1 ;
					END 
											
							
				End
				-----------------------------------------------------------------
				----ZOL - JARG - 2016/04/19 - R29308
				-----------------------------------------------------------------
				Set @Estado = 1	
			    EXEC @retval=dbo.Spza_Interfaces_ProcesarReservaXFactura  @id_usuario=@id_usuario, @id_fac_factura=@NewFacId
				IF @retval<>0
				BEGIN 
					IF @@TRANCOUNT > 0 
					BEGIN 
						ROLLBACK TRAN ;		
					END
					SET @ds_RespuestaJOB = 'Error actualizando la reserva';
					RETURN @retval;
				END
				-----------------------------------------------------------------
				----FIN ZOL - JARG - 2016/04/19 - R29308
				-----------------------------------------------------------------				
				DECLARE @msglog AS VARCHAR(8000)
				SET @msglog='La factura ' + @cd_fuente+'-'+@cd_serie+@cd_consecutivo + ' fue creada exitosamente'

				--Determinando si se debe auditar el proceso exitoso
				IF (@bl_as = 1) 
				BEGIN 										
					EXEC dbo.spzaAuditoria_Insertar  @id_proceso = @idproce    ,
													 @id_usuario = @id_usuario ,
													 @cd_status  = 1           , 												 
													 @admsg      = @msglog     ,
								 					 @msgparams  = NULL;
				END 			 			
				
	 		 	--Si la transaccion fue creada en el procedimiento entonces se actualiza--
				IF (XACT_STATE() <> 0) and (@@TRANCOUNT > 0) 
		   	    BEGIN 
				   COMMIT TRAN;				   
				END
				
				--Obtenemos los datos de los Rc automatico
				--SELECT 
				--	@cd_fuenteRC = cd_fuente_RcAuto
				--	, @cd_serieRC = cd_serie_RcAuto
				--	, @cd_consecutivoRC = cd_consecutivo_RcAuto
				--	, @cd_fuenteRCOtr = cd_fuente_RcOtrAuto
				--	, @cd_serieRCOtr = cd_serie_RcOtrAuto
				--	, @cd_consecutivoRCOtr = cd_consecutivo_RcOtrAuto
				--FROM dbo.fac_factura
				--WHERE id = @NewFacId
 
				--SELECT 	
				--	@cd_fuente+'-'+@cd_serie+@cd_consecutivo
				--	+'-'+CONVERT(VARCHAR(18),@NewFacId)									AS 'Respuesta', 
			 -- 		0																	AS 'Estado',
				--	IsNull(@cd_fuenteRC+'-'+@cd_serieRC+@cd_consecutivoRC,'')			AS 'RcAutomsg',
				--	IsNull(@cd_fuenteRCOtr+'-'+@cd_serieRCOtr+@cd_consecutivoRCOtr,'')	AS 'RcOtrAutomsg',
			 -- 		@Resolucionmsg														AS 'Resolucionmsg',
			 -- 		@NCF																AS 'NCF',
				--	@FechaCaducidad														AS 'FechaCaducidad'
				/*inicio rgelis 2012/10/11 req.10814*/
				IF @bl_generadaauto = 1	AND ISNULL(@Resolucionmsg,'')<> '' 
				BEGIN
					SET @MsjAlerta=ISNULL((@MsjAlerta+CHAR(13)+CHAR(10)),'')+ISNULL(@Resolucionmsg,'')
				END
				
				SELECT 	
					@cd_fuente+'-'+@cd_serie+@cd_consecutivo
					+'-'+CONVERT(VARCHAR(18),@NewFacId)									AS 'Respuesta', 
			  		0																	AS 'Estado',
					RC.ID																AS 'id_ReciboCaja',
					RC.id_FormaPago														AS 'id_FormaPago',
					FP.ds_nombre														AS 'ds_FormaPago',
					RC.cd_Fuente														AS 'cd_fuente',
					RC.cd_Serie															AS 'cd_serie',
					RC.cd_Consecutivo													AS 'cd_consecutivo',
					CASE RC.in_Tipo WHEN 1 THEN 'RC de Tiquetes' 
										   ELSE 'RC de otros Items'
									END													AS 'ds_Tipo',
					RC.am_valor															AS 'am_valor',
			  		CASE 
						WHEN 
							r.ds_num_resolucion IS NOT NULL 
							AND DATEDIFF(DAY,F.dt_fecha,r.dt_Fechavencimiento)<=ISNULL(r.in_diasvencimiento,0)
							AND ISNULL(r.in_diasvencimiento,0) > 0
							AND r.bl_alertarvencimiento = 1
							THEN 'Faltan ' + convert(VARCHAR,DATEDIFF(DAY,F.dt_fecha,r.dt_Fechavencimiento))  + ' dÃ­as para el vencimiento de la resoluciÃ³n'
						ELSE @Resolucionmsg END											AS 'Resolucionmsg',
			  		ISNULL(@NCF,'')														AS 'NCF',
					ISNULL(@FechaCaducidad,@dt_vence)									AS 'FechaCaducidad',
					ISNULL(@MsjAlerta,'')												AS 'ds_Alerta',
					@in_ConsecutivoUnicoDocumento										AS 'in_ConsecutivoUnicoDocumento',
					case when cd_fuente_NCausacionSrvTer is not null then isnull(cd_fuente_NCausacionSrvTer,'')+'-'+isnull(cd_serie_NCausacionSrvTer,'') + isnull(cd_consecutivo_NCausacionSrvTer,'') else '' end											AS 'DocumentoCausacionCxP'
				FROM dbo.fac_factura As F
					LEFT JOIN dbo.Fac_RecibosCaja As RC ON RC.id_fac_factura=F.id
					LEFT JOIN dbo.FormasPago As FP ON FP.id=RC.id_FormaPago 
					LEFT JOIN dbo.resoluciones r ON r.id_sucursal = F.id_sucursal AND r.ds_num_resolucion = F.ds_num_resolucion
				WHERE F.id = @NewFacId 	
				/*fin rgelis 2012/10/11 req.10814*/

				SELECT TOP 1 
					@ds_RespuestaJOB = ISNULL('Factura Creada: '+F.cd_fuente+'-'+F.cd_serie+F.cd_consecutivo+'-'+CONVERT(VARCHAR(18),F.id), '') + 
						CASE WHEN ISNULL(@MsjAlerta, '') <> '' THEN ' - Alerta: ' + @MsjAlerta ELSE '' END +
						CASE WHEN ISNULL(
							CASE WHEN r.ds_num_resolucion IS NOT NULL AND DATEDIFF(DAY,F.dt_fecha,r.dt_Fechavencimiento)<=ISNULL(r.in_diasvencimiento,0) AND ISNULL(r.in_diasvencimiento,0) > 0 AND r.bl_alertarvencimiento = 1 THEN 'Faltan ' + convert(VARCHAR,DATEDIFF(DAY,F.dt_fecha,r.dt_Fechavencimiento))  + ' dÃ­as para el vencimiento de la resoluciÃ³n' ELSE @Resolucionmsg END
						, '') <> '' THEN ' - Res: ' + 
							CASE WHEN r.ds_num_resolucion IS NOT NULL AND DATEDIFF(DAY,F.dt_fecha,r.dt_Fechavencimiento)<=ISNULL(r.in_diasvencimiento,0) AND ISNULL(r.in_diasvencimiento,0) > 0 AND r.bl_alertarvencimiento = 1 THEN 'Faltan ' + convert(VARCHAR,DATEDIFF(DAY,F.dt_fecha,r.dt_Fechavencimiento))  + ' dÃ­as para el vencimiento de la resoluciÃ³n' ELSE @Resolucionmsg END
						ELSE '' END +
						CASE WHEN ISNULL(RC.cd_fuente, '') <> '' THEN ' - Pago: ' + ISNULL(FP.ds_nombre, '') + ' ' + ISNULL(RC.cd_Fuente, '') + '-' + ISNULL(RC.cd_Serie, '') + '-' + ISNULL(RC.cd_Consecutivo, '') + ' (' + CASE RC.in_Tipo WHEN 1 THEN 'RC de Tiquetes' ELSE 'RC de otros Items' END + ') ' + ISNULL(CAST(RC.am_valor AS VARCHAR), '') ELSE '' END
				FROM dbo.fac_factura As F
					LEFT JOIN dbo.Fac_RecibosCaja As RC ON RC.id_fac_factura=F.id
					LEFT JOIN dbo.FormasPago As FP ON FP.id=RC.id_FormaPago 
					LEFT JOIN dbo.resoluciones r ON r.id_sucursal = F.id_sucursal AND r.ds_num_resolucion = F.ds_num_resolucion
				WHERE F.id = @NewFacId;
				
				RETURN @retval;
				
			END
		
			------------------------------------------------------------------------
			
	    END TRY 
    
    	-- Bloque CATCH (Manejo de excepciones)
    	BEGIN CATCH 
 
 			-- Tiempo de espera alcanzado --
		    IF ERROR_NUMBER() = 1222
		    BEGIN
      			SET @msg =  'No se pudo ejecutar el proceso. Tiempo de espera agotado.';
      			SET @retval = 1
      			
      			IF (@@TRANCOUNT > 0)
				BEGIN 
					ROLLBACK;
				END
	   	 
	   	        RAISERROR (@msg,16,125);
	   	       	--Se debe auditar proceso fallido
				IF (@bl_af = 1) EXEC dbo.spzaAuditoria_Insertar  @id_proceso = @idproce ,
													 			 @id_usuario = @id_usuario ,
													 			 @cd_status  = 0           , 
													 			 @admsg      = @msg	   ;														 			 		
	   	        SET @ds_RespuestaJOB = @msg;
				RETURN @retval;
		    END
		    
		    -- Registro bloqueado / Conflicto de actualizacion
		    ELSE 
		    IF ERROR_NUMBER() IN (1205, 3960)
    		BEGIN
    		
    			IF (@@TRANCOUNT > 0)
				BEGIN 
					ROLLBACK;
				END
	   	        
		       	SET @retry     = 1              ;
		       	SET @retrycont = @retrycont + 1 ; 
	   	 	END
	    	ELSE
		    BEGIN
		     	-- Error no manejado --					
				IF (@@TRANCOUNT > 0)
				BEGIN 
					ROLLBACK;
				END	
													
				SET @retval = 1;
 				SET @msg =	'Ha ocurrido un error. InformaciÃ³n para soporte tecnico:'			+ CHAR(13)+ CHAR(10) + CHAR(13)+ CHAR(10) +
						    'Numero: ' + isnull(CAST(ERROR_NUMBER()   AS VARCHAR(10)),'') 		+ CHAR(13)+ CHAR(10) + CHAR(13)+ CHAR(10) +
							'Mensaje: ' + isnull(ERROR_MESSAGE(),'') 					   		+ CHAR(13)+ CHAR(10) + CHAR(13)+ CHAR(10) +
						 	'Severidad: ' + isnull(CAST(ERROR_SEVERITY() AS VARCHAR(10)),'') 	+ CHAR(13)+ CHAR(10) + CHAR(13)+ CHAR(10) +
						 	'Estado: ' + isnull(CAST(ERROR_STATE()    AS VARCHAR(10)),'') 		+ CHAR(13)+ CHAR(10) + CHAR(13)+ CHAR(10) +
							'Procedimiento: ' + 'spza_FacturaJOB_Crear'							+ CHAR(13)+ CHAR(10) + CHAR(13)+ CHAR(10) +
							'Linea: ' + isnull(CAST(ERROR_LINE() 	   AS VARCHAR(10)),'')      + CHAR(13)+ CHAR(10) + CHAR(13)+ CHAR(10) ; 							
	
				--Se debe auditar proceso fallido
				IF (@bl_af = 1) EXEC dbo.spzaAuditoria_Insertar	@id_proceso = @idproce   ,
										 			 			@id_usuario = @id_usuario ,
										 			 			@cd_status  = 0           , 
										 			 			@admsg      = @msg	  ;	
				--RAISERROR (@msg,16,126);
				--SET @ds_RespuestaJOB = @msg;
				SET @ds_RespuestaJOB = @msg;
				RETURN @retval;
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
  		--RAISERROR (@msg,16,127);
  		SET @ds_RespuestaJOB = @msg;
		RETURN @retval;
  	END   	
    
    RETURN @retval;
END
GO

