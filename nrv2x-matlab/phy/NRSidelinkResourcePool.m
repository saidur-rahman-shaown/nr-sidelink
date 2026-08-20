% NRSidelinkResourcePool Resource pool for NR V2X sidelink communications
%   NRSidelinkResourcePool models a single resource pool configured by a 
%   a subset of the fields contained in the SL-ResourcePool-r16
%   information element (TS 38.331 section 6.3.5), along with additional 
%   general parameters. The class can combine these semi-static RRC 
%   parameters with dynamic DCI/SCI supplied parameters to create PSCCH 
%   and PSSCH baseband waveform transmissions in a slot. Use the 
%   rmcTestConfiguration static method to create default semi-static and 
%   dynamic parameter sets based on the TS 38.101-4 Annex A.6.2 PSSCH 
%   reference measurement channels.
% 
%   NRSidelinkResourcePool properties:
% 
%   SCSCarrier                - SCS carrier dimension and numerology, and current slot number in resource pool
%                               (default nrCarrierConfig('SubcarrierSpacing',30,'NSizeGrid',51))
%   NStartBWP                 - CRB of lowest RB in the BWP associated with the resource pool
%                               (default 0)
%   NSizeBWP                  - Number of PRB in the BWP associated with the resource pool
%                               (0...275) (default 51)
%   sl_StartSymbol_r16        - The starting symbol used for sidelink in a slot without SL-SSB
%                               (0...7) (default 0)
%   sl_LengthSymbols_r16      - Number of symbols used for sidelink in a slot without SL-SSB
%                               (7...14) (default 14)
%   sl_SubchannelSize_r16     - Number of PRB in a subchannel of the resource pool
%                               (10 (default), 12, 15, 20, 25, 50, 75, 100)
%   sl_StartRB_Subchannel_r16 - Lowest RB index of the subchannel with the lowest index in the 
%                               resource pool, with respect to the lowest RB index of the SL BWP
%                               (0...265) (default 0)
%   sl_NumSubchannel_r16      - The number of subchannels in the resource pool
%                               (1...27) (default 5)
%   sl_X_Overhead_r16         - The overhead accounting for CSI-RS and PT-RS
%                               (0 (default), 3, 6, 9)
%   sl_Scaling_r16            - The scaling factor used to limit the number of resource elements assigned to the second stage SCI on PSSCH
%                               (0.5, 0.65, 0.8, 1 (default))
%   sl_TimeResourcePSCCH_r16  - The number of symbols of PSCCH in the resource pool
%                               (2 (default), 3)
%   sl_FreqResourcePSCCH_r16  - The number of PRBs for PSCCH in a resource pool (not greater than the number PRBs of the subchannel)
%                               (10 (default), 12, 15, 20, 25)
%   sl_DMRS_ScrambleID_r16    - The initialization value for PSCCH DM-RS scrambling
%                               (0...65535) (default 0)
%   sl_PSFCH_Period_r16       - The period of PSFCH resource in the unit of slots within the resource pool
%                               (0 (default), 1, 2, 4)
%   MaxNumSubchannels         - Read-only. Maximum number of subchannels of sl_SubchannelSize_r16 size that could fit into the BWP
%   IsPSFCHSlot               - Read-only. Indicates whether the current slot in pool can contain PSFCH candidates
%
%   NRSidelinkResourcePool methods:
%
%   rmcTestConfiguration - PSSCH RMC transmission and resource pool configuration parameters (static)
%   transmitInPool       - Create baseband IQ of SCI1 (PSCCH), SCI2 and SL-SCH (PSSCH) transmission in current resource pool slot
%   receiveInPool        - Decode SCI1 (PSCCH), SCI2 and SL-SCH (PSSCH) transmissions in current resource pool slot
%   advanceToNextSlot    - Advance to next available slot in the resource pool
%   getWaveformInfo      - Get information about modulated baseband IQ waveform
%   getPSCCHResources    - Get PSCCH resources given PSCCH transmission parameters
%   getPSSCHResources    - Get PSSCH resources given PSSCH transmission parameters
%   getTBS               - Get SL-SCH TBS given PSSCH transmission parameters
%   displayTransmissionResources - Display the PSCCH and PSSCH resource mapping given PSCCH & PSSCH transmission parameters
%
%   Many of the class methods take a single structure which gathers
%   together the dynamic PSCCH/PSSCH parameters defining paired PSCCH and
%   PSCCH transmissions in a slot. Use the rmcTestConfiguration static 
%   method to create a fully populated parameter structure. This structure 
%   contains the following fields: 
%  
%   SubchannelAllocation - Subchannels allocated to PSSCH, specified as [nstartsubCH, LsubCH] (default [0 2])          
%   NumLayers            - Number of transmission layers associated with PSSCH (1 (default),2)
%   Modulation           - Modulation scheme associated with SL-SCH on PSSCH ("QPSK" (default),"16QAM","64QAM","256QAM")
%   NumDMRSPositions     - Number of PSSCH DM-RS symbols (1,2,3,4 (default))
%   NumDMRSPositionsList - List of all PSSCH DM-RS symbols configured for UE ([] (default),1,2,3,4)
%   TargetCodeRate       - Target code rate associated with SL-SCH and SCI2 on PSSCH (0 < tcr < 1) (default 308/1024)
%   BetaSCI2Offset       - Rate-matching offset associated with SCI2 on PSSCH (1.125 <= beta <= 20) (default 3.5)
%   OSCI2                - Number of information bits for SCI2 payload on PSSCH (default 35)
%   RedundancyVersion    - RV index associated with SL-SCH on PSSCH (0 (default),1,2,3)
%   HARQProcessID        - HARQ process ID of SL-SCH on PSSCH (0...15) (default 0)
%   PSFCHOverhead        - PSFCH overhead indication associated with PSSCH (0 (default),1)
%   NXID                 - Decimal representation of PSCCH CRC (SCI1) (default [])
%   OSCI1                - Number of information bits for SCI1 payload on PSCCH (default 26)  

%   Copyright 2022-2024 The MathWorks, Inc.

classdef NRSidelinkResourcePool
    
    properties

        SCSCarrier(1,1) nrCarrierConfig = nrCarrierConfig('SubcarrierSpacing',30,'NSizeGrid',51);          % 51 RB for 20 MHz BW @ 30 kHz SCS, 106 RB for 40 MHz BW @ 30 kHz SCS

        NStartBWP {mustBeScalarOrEmpty,mustBeInteger,mustBeNonnegative} = [];                              % Encoded into RIV in BWP.locationAndBandwidth
        NSizeBWP {mustBeScalarOrEmpty,mustBeInteger,mustBeInRange(NSizeBWP,0,275)} = [];                   % Encoded into RIV in BWP.locationAndBandwidth
 
        sl_StartSymbol_r16(1,1) {mustBeInteger,mustBeInRange(sl_StartSymbol_r16,0,7)} = 0;                 % SL-BWP-Generic-r16.sl-StartSymbol-r16         ENUMERATED {sym0, sym1, sym2, sym3, sym4, sym5, sym6, sym7}
        sl_LengthSymbols_r16(1,1) {mustBeInteger,mustBeInRange(sl_LengthSymbols_r16,7,14)} = 14;           % SL-BWP-Generic-r16.sl-LengthSymbols-r16       ENUMERATED {sym7, sym8, sym9, sym10, sym11, sym12, sym13, sym14}
  
        sl_SubchannelSize_r16(1,1) {mustBeMember(sl_SubchannelSize_r16,[10 12 15 20 25 50 75 100])} = 10;  % SL-ResourcePool-r16.sl-SubchannelSize-r16     ENUMERATED {n10, n12, n15, n20, n25, n50, n75, n100}  Size of a subchannel
        sl_StartRB_Subchannel_r16(1,1) {mustBeInteger,mustBeInRange(sl_StartRB_Subchannel_r16,0,265)} = 0; % SL-ResourcePool-r16.sl-StartRB-Subchannel-r16 INTEGER (0..265)   Offset of lowest RB of lowest subchannel of resource and the *lowest RB of the BWP*
        sl_NumSubchannel_r16(1,1) {mustBeInteger,mustBeInRange(sl_NumSubchannel_r16,1,27)} = 5;            % SL-ResourcePool-r16.sl-NumSubchannel-r16      INTEGER (1..27)    Number of subchannels in resource pool. 5 for 20 MHz and 10 for 10 MHz

        sl_X_Overhead_r16(1,1) {mustBeMember(sl_X_Overhead_r16,[0 3 6 9])} = 0;                            % SL-ResourcePool-r16.sl-X-Overhead-r16         ENUMERATED {n0,n3, n6, n9}

        sl_Scaling_r16(1,1) {mustBeMember(sl_Scaling_r16,[0.5 0.65 0.8 1])} = 1;                           % SL-PSSCH-Config-r16.sl-Scaling-r16            ENUMERATED {f0p5, f0p65, f0p8, f1}  sl-Scaling-r16 in SL-PSSCH-Config-r16, in the PSSCH-Config of the pool configuration (0.5, 0.65, 0.8, 1)

        sl_TimeResourcePSCCH_r16(1,1) {mustBeMember(sl_TimeResourcePSCCH_r16,[2 3])} = 2;                  % SL-PSCCH-Config-r16.sl-TimeResourcePSCCH-r16  ENUMERATED {n2, n3}
        sl_FreqResourcePSCCH_r16(1,1) {mustBeMember(sl_FreqResourcePSCCH_r16,[10 12 15 20 25])} = 10;      % SL-PSCCH-Config-r16.sl-FreqResourcePSCCH-r16  ENUMERATED {n10,n12, n15, n20, n25} , and no larger than pool subchannel size
        sl_DMRS_ScrambleID_r16(1,1) {mustBeInteger,mustBeInRange(sl_DMRS_ScrambleID_r16,0,65535)} = 0;     % SL-PSCCH-Config-r16.sl-DMRS-ScrambleID-r16    INTEGER (0..65535)

        sl_PSFCH_Period_r16(1,1) {mustBeMember(sl_PSFCH_Period_r16,[0 1 2 4])} = 0 ;                       % SL-PSFCH-Config-r16.sl-PSFCH-Period-r16       ENUMERATED {sl0, sl1, sl2, sl4} Values are 0, 1, 2, 4 (0 signifies that there is no PSFCH (HARQ feedback) in the pool)

    end

    % Read-only properties
    properties (Dependent, SetAccess=private)
        MaxNumSubchannels;  % Maximum number of subchannels of the associated subchannel size that could fit into the BWP
        IsPSFCHSlot;        % Is the current slot a PSFCH candidate opportunity
    end

    methods

        function [baseband,sld,slo] = transmitInPool(pool,transmission,sci1bits,sci2bits,slsch)
        %transmitInPool Transmit SCI1, SCI2 and SL-SCH information bits in current slot of resource pool
            [baseband,resourcegrid,ccsymbols,symbols,slo,sld] = outertransmit(pool,transmission,slsch,sci2bits,sci1bits); %#ok<ASGLU>
            sld.ResourceGrid = resourcegrid;  % Assign resource grid into intermediate data processing bundle
        end
        
        function [eset,sld,slo] = receiveInPool(pool,transmission,baseband,slschrx,decalgo)
        %receiveInPool Decode PSCCH/PSSCH physical channels and transport channel/control coding
            if nargin < 5
                decalgo = struct(PerfectChannelEstimator = 0);
            end
            [eset,sld,slo] = receiveInPool(pool,transmission,baseband,slschrx,decalgo);  % Despatch to file local version
        end

       function minfo = getWaveformInfo(pool)
        %getWaveformInfo Get information about modulated IQ waveform
            minfo = nrOFDMInfo(pool.SCSCarrier);
        end      
        
        function [pool,nslots] = advanceToNextSlot(pool)
        %advanceToNextSlot Advance to next available slot defined in resource pool
            nslots = 1;     % Number of slots advanced from current slot to next available slot in pool (will depend on SL-ResourcePool-r16.sl-TimeResource-r16 bit string and SLSS config)
            pool.SCSCarrier.NSlot = pool.SCSCarrier.NSlot + nslots;
        end

        function displayTransmissionResources(pool,transmission)
        %displayTransmissionResources Display PSCCH and PSSCH resources associated with a PSCCH/PSSCH transmission in pool

            sloc = getPSCCHResources(pool,transmission);
            slod = getPSSCHResources(pool,transmission);

            % Map data onto physical resources of slot
            resourcegrid = nrResourceGrid(pool.SCSCarrier,transmission.NumLayers);
            chnames = string([]);
            chvals = [];
            % Nested function to build up resource data for plotting
            function map2grid(n,i,v)
                resourcegrid(i+1) = v;
                chnames(end+1) = n;
                chvals(end+1) = v;
            end

            % Color map values for the display

            % PSCCH
            powerPSSCH = 30;
            powerPSSCHDMRS = 110;

            % PSSCH
            powerPSCCH = 195;       % SL-SCH part
            powerPSCCHDMRS = 240;

            % PSCCH
            map2grid("PSCCH (SCI1)",sloc.PSCCHIndices,powerPSCCH);           % PSCCH
            map2grid("PSCCH DM-RS",sloc.PSCCHDMRSIndices,powerPSCCHDMRS);    % PSCCH DM-RS

            % PSSCH
            map2grid('PSSCH (SCI2)',slod.PSSCHIndicesSplit{1},powerPSSCH+30);% PSSCH - SCI2 part
            map2grid('PSSCH (SL-SCH)',slod.PSSCHIndicesSplit{2},powerPSSCH); % PSSCH - SL-SCH part
            map2grid("PSSCH DM-RS",slod.PSSCHDMRSIndices,powerPSSCHDMRS);    % PSSCH DM-RS

            % Create the replicated leading sidelink symbol, compressing the colors into a green band
            resourcegrid(:,pool.sl_StartSymbol_r16+1,:) = (resourcegrid(:,pool.sl_StartSymbol_r16+2,:)~=0) .* (120+0.2*resourcegrid(:,pool.sl_StartSymbol_r16+2,:));
            % Associated legend entry
            chnames(end+1) = "Repeated symbol";
            chvals(end+1) = fix(120+0.2*(powerPSCCHDMRS-powerPSSCH)/2);

            figure;
            image(resourcegrid(:,:,1));  % Display first port/antenna of grid only
            axis xy;
            title('PSCCH and PSSCH Resource Mapping');
            subtext = ["without" "with"];
            subtitle(sprintf('Slot %s PSFCH Symbols (NSlot=%d)',subtext(pool.IsPSFCHSlot+1), pool.SCSCarrier.NSlot));
            xlabel('Symbols in Slot'); ylabel('Resource Elements');

            % Draw a set of colored lines for the legend
            hold on;
            N = length(chvals);
            L = line(ones(N),ones(N), 'LineWidth',6);                   % Array of lines for the channel signals
 
            % Set the lines colors according to color map and create the legend
            cmap = colormap;
            set(L,{'color'},mat2cell(cmap( min(1+chvals,length(cmap) ),:),ones(1,N),3));   % Set the colors of lines according to cmap

            legend(chnames);

        end

        function slo = getPSCCHResources(pool,transmission)
        %getPSCCHResources Get resource information associated with PSCCH transmission in pool
            slo = getPSCCHResources(pool,transmission); % Despatch to file local function
        end

        function slo = getPSSCHResources(pool,transmission)
        %getPSSCHResources Get resource information associated with PSSCH transmission in pool
            slo = getPSSCHResources(pool,transmission); % Despatch to file local function
        end

        function tbs = getTBS(pool,transmission)
        %getTBS Get TBS value associated with PSSCH transmission configuration
    
            % Prep and check the input parameters
            transmission = expandTransmissionParameters(pool,transmission);

            % Q'_SCI2 (before gamma) per TS 38.212 Sec 8.4.4
            [qdsci2_1,npsschsymbols] = calculateQprimeSCI2(pool,transmission);

            % TS 38.214 section 8.1.3.2
            if ~isempty(transmission.NumDMRSPositionsList)
                ndmrslist = transmission.NumDMRSPositionsList;
            else
                ndmrslist = transmission.NumDMRSPositions;
            end
            ndmrsre = 6*sum(ndmrslist)/numel(ndmrslist);   % 'Average' number of DM-RS RE per PRB across symbols, for all DM-RS configured (38.214 section 8.1.3.2)
            xoh = pool.sl_X_Overhead_r16;                  % Signalled overhead in a single RB across sidelink symbols
            nreprime = 12*npsschsymbols - xoh - ndmrsre;   % Number of data RE in a single RB across all the allocation symbols
            nre = nreprime*transmission.SubchannelAllocation(2)*pool.sl_SubchannelSize_r16 - 12*pool.sl_FreqResourcePSCCH_r16*pool.sl_TimeResourcePSCCH_r16 - qdsci2_1;   % Latter is number of coded modulation symbols for SCI2, assuming gamma = 0
            tbs = nrTBS(transmission.Modulation,transmission.NumLayers,nre,1,transmission.TargetCodeRate);  % NOTE: Put 'nre' in the nPRB input position and set nreperprb = 1 to get past the internal nre calculation, before stage 2 of process
        end
        
    end

    methods (Static)
    
        % PSSCH RMC and conformance test parameters
        function [varargout] = rmcTestConfiguration(varargin)
        %rmcTestConfiguration Get PSSCH, resource pool and test configurations associated with RAN4 specifications
            [varargout{1:nargout}] = rmcparams(varargin{:}); % Call the file local implementation function
        end
        
    end

    methods 

        function maxsubch = get.MaxNumSubchannels(pool)
            [~,bwpsize] = getWorkingBWPDims(pool);
            maxsubch = fix((bwpsize - pool.sl_StartRB_Subchannel_r16)/pool.sl_SubchannelSize_r16);
        end

        function fslot = get.IsPSFCHSlot(pool)
            fslot = pool.sl_PSFCH_Period_r16 && (mod(pool.SCSCarrier.NSlot,pool.sl_PSFCH_Period_r16)==0);
        end
    end

    methods (Access = private)
        
        function validateConfig(pool)
        % Resource pool cross-property checking 

            % Time resource checks
            % 
            % Check that the sidelink symbol set fits into a slot
            if (pool.sl_StartSymbol_r16+pool.sl_LengthSymbols_r16) > pool.SCSCarrier.SymbolsPerSlot
                error('Resource pool symbol configuration does not fit into the associated BWP slot (symbols per slot=%d).',pool.SCSCarrier.SymbolsPerSlot);
            end

            % Frequency resource checks
            % 
            % Check that the BWP fits into the SCS carrier
            [bwpstart,bwpsize] = getWorkingBWPDims(pool);
            if (bwpstart < pool.SCSCarrier.NStartGrid) || ((bwpstart + bwpsize) > (pool.SCSCarrier.NStartGrid + pool.SCSCarrier.NSizeGrid))
                error('BWP (NStartBWP=%d,NSizeBWP=%d) does not fit into the associated SCS carrier (NStartGrid=%d,NSizeGrid=%d).',...
                        bwpstart,bwpsize,pool.SCSCarrier.NStartGrid,pool.SCSCarrier.NSizeGrid);
            end

            % Check that the subchannel set fits into the BWP
            if (pool.sl_NumSubchannel_r16*pool.sl_SubchannelSize_r16 + pool.sl_StartRB_Subchannel_r16) > bwpsize
                error('Resource pool subchannel configuration (%d subchannels of %d PRBs each, starting at PRB %d) does not fit into the associated BWP resource blocks (NSizeBWP=%d).',...
                    pool.sl_NumSubchannel_r16,pool.sl_SubchannelSize_r16,pool.sl_StartRB_Subchannel_r16,...
                    bwpsize);
            end
            % Check that the PSCCH fits into a subchannel
            if pool.sl_FreqResourcePSCCH_r16 > pool.sl_SubchannelSize_r16
                error('The number of PRBs configured for the PSCCH (%d) cannot be greater than the subchannel size (%d)',pool.sl_FreqResourcePSCCH_r16,pool.sl_SubchannelSize_r16);
            end

        end

    end

    methods (Access = private)
        
       % Transmit PSCCH/PSSCH into slot of the resource pool (joint 38.211/38.212 processing)
       % - Transmission configured by resource pool and semi-static/dynamic transmission parameters
       % - Data input is SL-SCH transport block and SCI1/SCI2 information bits
       % - Transmission returned as baseband time series and as underlying resources
       function [baseband,resourcegrid,ccsymbols,symbols,slo,sld] = outertransmit(pool,transmission,slsch,sci2bits,sci1bits)
              
           persistent localtransport;

           rv = transmission.RedundancyVersion;
           harqid = transmission.HARQProcessID;

           % Get the PSCCH/PSSCH resources associated with the transmission
           sloc = getPSCCHResources(pool,transmission);
           slod = getPSSCHResources(pool,transmission);

           % If the 'slsch' input is explicit data then use the local transport encoder
           if isnumeric(slsch)
                if isempty(localtransport)
                   localtransport = nrULSCH;
                end
                localtransport.setTransportBlock(slsch);
                slsch = localtransport;
           end

           % Get PSSCH codeword (SL-SCH part) from SL-SCH transport channel object
           % 
           % Workaround for the static restriction on the function syntax, depending on whether the MultipleHARQProcesses property had been set or not
           % PDSCHBITS = step(DLSCH,MODULATION,NLAYERS,OUTCWLEN,RV)
           % PDSCHBITS = step(DLSCH,MODULATION,NLAYERS,OUTCWLEN,RV,HARQID)
           if slsch.MultipleHARQProcesses
                psschbits = slsch(transmission.Modulation,transmission.NumLayers,slod.PSSCHG(2),rv,harqid);
           else
                psschbits = slsch(transmission.Modulation,transmission.NumLayers,slod.PSSCHG(2),rv);
           end

           % Encode the SCI1 info bits for PSCCH
           [pscchbits,nxid] = sciEncode(sci1bits,sloc.PSCCHG,0); % Encode and rate match SCI1

           % Encode the SCI2 info bits for PSSCH
           psschsci2bits = sciEncode(sci2bits,slod.PSSCHG(1),1); % Encode and rate match SCI2 (note that I_BIL = 1 for SCI2 ratematching)

           % Pass the CRC NXID on to the physical channel processing
           % In the case where there is no PSCCH joint transmission, 
           % the NXID would come from the parameters...
           if isempty(transmission.NXID)
                transmission.NXID = nxid;
           end

           % Transmit the codewords on the PSCCH and PSSCH physical channels
           [baseband,resourcegrid,ccsymbols,symbols,occselected,slo] = transmit(pool,transmission,pscchbits,psschsci2bits,psschbits);

           % External data processing access - intermediate processing data points
           sld = struct();

           % Data and control information bits (input to the coding - 38.211)
           % 
           sld.SCI1Bits = sci1bits;            % SCI1 information bits for PSCCH
           sld.PSCCHBits = pscchbits;          % SCI1 codeword bits for PSCCH
           sld.PSCCHSymbols = ccsymbols;       % PSCCH symbols, in mapping order
           sld.PSCCHDMRSOCCIndex = occselected;% PSCCH DM-RS OCC selected for this transmission
           sld.NXID = nxid;                    % NXID that was used for PSSCH scrambling (from the PSCCH/SCI1 CRC value)   
           % 
           sld.SCI2Bits = sci2bits;            % SCI2 information bits for PSSCH
           sld.SLSCHBits = slsch.getTransportBlock(harqid);  % Get the TB bits out of the SL-SCH processor
           sld.PSSCHSCI2Bits = psschsci2bits;  % SCI2 codeword bits for PSSCH      
           sld.PSSCHSLSCHBits = psschbits;     % SL-SCH codeword bits for PSSCH
           sld.PSSCHSymbols = symbols;         % PSSCH symbols, in mapping order (concatenated SCI2 and SL-SCH parts)

       end

        % Transmit transport and control coded codewords into PSCCH/PSSCH (38.211 processing) - the transport and source code has already been done
        function [baseband,resourcegrid,ccsymbols,symbols,occselected,slo] = transmit(pool,transmission,controlbits,controlpartbits,datapartbits)

            % Get the resource allocations for channel mapping
            [slo,occselected] = getPSCCHResources(pool,transmission);
            slo = getPSSCHResources(pool,transmission,slo);

            % Physical channel processing (PSCCH and PSSCH)
            [ccsymbols,symbols] = physicalcodeup(transmission,controlbits,controlpartbits,datapartbits);

            % Map data onto physical resources of slot
            resourcegrid = nrResourceGrid(pool.SCSCarrier,transmission.NumLayers);
            
            % PSCCH
            % Linear power scaling on transmission components
            powerPSCCH = 1;
            powerPSCCHDMRS = 1;    
            resourcegrid(slo.PSCCHIndices+1) = powerPSCCH*ccsymbols;
            resourcegrid(slo.PSCCHDMRSIndices+1) = powerPSCCHDMRS*slo.PSCCHDMRS;

            % PSSCH
            % Linear power scaling on transmission components
            powerPSSCH = 1;
            powerPSSCHDMRS = 1;     
            resourcegrid(slo.PSSCHIndices+1) = powerPSSCH*symbols;
            resourcegrid(slo.PSSCHDMRSIndices+1) = powerPSSCHDMRS*slo.PSSCHDMRS;

            % Create the replicated leading sidelink symbol
            resourcegrid(:,pool.sl_StartSymbol_r16+1,:) =  resourcegrid(:,pool.sl_StartSymbol_r16+2,:);

            % OFDM modulation
            % No windowing to stop wraparound in the single slot
            baseband = nrOFDMModulate(pool.SCSCarrier,resourcegrid,'Windowing',0);

        end

    end

end

% --------------------------------------------------------------
% 
% FILE LOCAL FUNCTIONS
% 
% --------------------------------------------------------------


% Get the active BWP dimensions
function [bwpstart,bwpsize] = getWorkingBWPDims(pool)
    bwpstart = pool.NStartBWP;
    if isempty(bwpstart)
        bwpstart = pool.SCSCarrier.NStartGrid;
    end
    bwpsize = pool.NSizeBWP;
    if isempty(bwpsize)
        bwpsize = pool.SCSCarrier.NSizeGrid;
    end
end


function varargout = rmcparams(rmc,bwv,scsv,modv)
    
    % Prepare any overriding numerology inputs
    if nargin < 4 || isempty(modv)
        modv = 'QPSK';
        if nargin < 3 || isempty(scsv)
            scsv = 30;
            if nargin < 2 || isempty(bwv)
                bwv = 20;
            end
        end
    end

    % TS 38.104 Table 5.3.2-1:   Transmission bandwidth configuration NRB for FR1
    % TS 38.101-1 Table 5.3.2-1: Maximum transmission bandwidth configuration NRB (FR1)
    % NRB, for BW and SCS
    scsvals  = [15 30 60];
    bwvals   = [5   10 15 20  25  30  35  40  45  50  60  70  80  90  100];    % MHz
    nrbtable = [25  52 79 106 133 160 188 216 242 270 NaN NaN NaN NaN NaN;     % 15 kHz
                11  24 38 51  65  78  92  106 119 133 162 189 217 245 273;     % 30 kHz
                NaN 11 18 24  31  38  44  51  58  65  79  93  107 121 135];    % 60 kHz
    
    msel1 = (scsv==scsvals);
    msel2 = (bwv==bwvals);
    nrb = nrbtable(msel1,msel2);
    if isempty(nrb) || isnan(nrb)
        error('The BW (%d MHz) and SCS (%d kHz) combination is not supported in NR FR1.',bwv,scsv);
    end

    % Return the pool
    % Return the measurement channel
    % Return the associated test setup configuration 
    %
    % Supported measurement channels:
    % TS 38.101-4 Section 11 V2X requirements, and Appendix A.6.2 Reference measurement channels for PSSCH performance requirements
    % TS 38.521-1 Annex A.7 V2X reference measurement channels
    rmcnames = ["R.PSSCH.2-1.1";
                "R.PSSCH.2-1.2";
                "R.PSSCH.2-1.3";
                "R.PSSCH.2-1.4";
                "R.PSSCH.2-1.5";
                "FRC"];

    % If a single "names" input then return all the options 
    if nargin == 1 && strcmpi(rmc,"names")
        varargout = {rmcnames};
        return;
    end

    if nargin == 0
        rmc = rmcnames(1);
    end

    % Get a pool object and update the numerology related parameters
    % given the input arguments
    pool = NRSidelinkResourcePool;
    pool.SCSCarrier.NSizeGrid = nrb;
    pool.SCSCarrier.SubcarrierSpacing = scsv;
    pool.SCSCarrier.NSlot = 1;
    pool.sl_NumSubchannel_r16 = pool.MaxNumSubchannels;
    pool.sl_PSFCH_Period_r16 = 4;

    % Get a PSCCH/PSSCH transmission structure
    transmission = expandTransmissionParameters(pool,struct());  % This call syntax gets the default set of transmission parameters
    
    % Create a test configuration structure
    testconfig = struct('DelayProfile','TDLA30');

    % PSSCH layers
    transmission.NumLayers = 1;            % Dynamic, SCI1 signalled number of layers

    % TS 38.101-4 Section 11 V2X requirements, and Appendix A.6.2 Reference measurement channels for PSSCH performance requirements
    % TS 38.521-1 Annex A.7 V2X reference measurement channels
    switch rmc
        case 'R.PSSCH.2-1.1'
            % R.PSSCH.2-1.1
            % For PSSCH demodulation requirements - 2Rx requirements - Test 1
            transmission.SubchannelAllocation = [0 2];
            transmission.Modulation = 'QPSK';
            transmission.TargetCodeRate = 308/1024;   % MCS 4, CR = 0.3
            transmission.NumDMRSPositions = 4;
            transmission.NumDMRSPositionsList = [3,4]; 
            transmission.BetaSCI2Offset = 3.5;
        
            % TDLA30-2700
            testconfig.MaximumDopplerShift = 2700; 
            testconfig.ReferenceSNR = 3.4; 
   
        case 'R.PSSCH.2-1.2'
            % R.PSSCH.2-1.2
            % For PSSCH demodulation requirements - 2Rx requirements - Test 2
            transmission.SubchannelAllocation = [0 2];
            transmission.Modulation = '16QAM';
            transmission.TargetCodeRate = 378/1024;   % MCS 11, CR = 0.37
            transmission.NumDMRSPositions = 3; 
            transmission.NumDMRSPositionsList = [2,3]; 
            transmission.BetaSCI2Offset = 5;
        
            % TDLA30-1400
            testconfig.MaximumDopplerShift = 1400; 
            testconfig.ReferenceSNR = 8.8; 

        case 'R.PSSCH.2-1.3'
            % R.PSSCH.2-1.3
            % For PSSCH demodulation requirements - 2Rx requirements - Test 3
            transmission.SubchannelAllocation = [0 1];
            transmission.Modulation = '64QAM';
            transmission.TargetCodeRate = 438/1024;   % MCS 17, CR = 0.43
            transmission.NumDMRSPositions = 2;
            transmission.NumDMRSPositionsList = [2,2];
            transmission.BetaSCI2Offset = 5;
        
            % TDLA30-180;
            testconfig.MaximumDopplerShift = 180; 
            testconfig.ReferenceSNR = 14.8; 

        case 'R.PSSCH.2-1.4'
            % R.PSSCH.2-1.4
            % For power imbalance performance with two links - Test 1
            transmission.SubchannelAllocation = [0 1];
            transmission.Modulation = 'QPSK';
            transmission.TargetCodeRate = 308/1024;   % MCS 4, CR = 0.3
            transmission.NumDMRSPositions = 3; 
            transmission.NumDMRSPositionsList = [2,3];
            transmission.BetaSCI2Offset = 3.5;

            % AWGN onlytest
            testconfig.MaximumDopplerShift = 0; 
            testconfig.ReferenceSNR = 4.8;  % Measurement channel ref SNR, not the 'interferer' UE...

        case 'R.PSSCH.2-1.5'
            % R.PSSCH.2-1.5
            % For HARQ buffer soft combining test - Test 1
            transmission.SubchannelAllocation = [0 1];
            transmission.Modulation = '64QAM';
            transmission.TargetCodeRate = 910/1024;   % MCS 27, CR = 0.89
            transmission.NumDMRSPositions = 2;
            transmission.NumDMRSPositionsList = 2;
            transmission.BetaSCI2Offset = 2.5;
            
            % AWGN only test
            testconfig.MaximumDopplerShift = 0; 
            testconfig.ReferenceSNR = 10.9;   % 5% BLER
    
        case 'FRC'
            % TS 38.521-1 Annex A.7 V2X reference measurement channels
        
            % No HARQ feedback in pool
            pool.sl_PSFCH_Period_r16 = 0;

            % Find the smallest subchannel size which maximizes the NRB which can be used
            subchsvals = [10,12,15,20,25,50,75,100];
            used = subchsvals.*fix(nrb./subchsvals);
            mostused = max(used);
            selsubchsize = subchsvals(find(used==mostused,1,'first'));
      
            % Assign subchannel config
            pool.sl_SubchannelSize_r16 = selsubchsize;
            pool.sl_NumSubchannel_r16 = pool.MaxNumSubchannels; % Update the pool size for the new subchannel size
        
            % Assign common pool parameters
            pool.sl_FreqResourcePSCCH_r16 = 10;
            pool.sl_TimeResourcePSCCH_r16 = 3;
        
            % Update PSSCH transmission parameters
        
            % Assign the PSSCH resource allocation to use all subchannels
            transmission.SubchannelAllocation = [0,pool.MaxNumSubchannels];
        
            % Assign the MCS related parameters
            % 
            % Extend to include "16QAM", for overall consistency and ease of application
            modvals = ["QPSK" "16QAM" "64QAM" "256QAM"];
            tcrvals = [308 490 772 797]/1024;   % Associated MCS indices are 4,13,24 (all 64QAM table) and 23 (256QAM table)
            betaoffset2vals = [2.25 3.5 6.25 6.25];
        
            msel = find(modv==modvals);
            transmission.Modulation = modv;  
            transmission.TargetCodeRate = tcrvals(msel);
            transmission.BetaSCI2Offset = betaoffset2vals(msel);
        
            % Assign common parameters
            transmission.NumDMRSPositions = 2;
            transmission.NumDMRSPositionsList = 2;
      
            % AWGN only test
            testconfig.MaximumDopplerShift = 0; 
            testconfig.ReferenceSNR = 10.9;   % 5% BLER

    otherwise
        error('Invalid RMC name. Must be one of %s',join(rmcnames,', '));
   end

   % In the case of the RMC, check whether any overriding of the carrier dimensions
   % has limited the RMC subchannel allocation
   if transmission.SubchannelAllocation(2) > pool.MaxNumSubchannels
        warning('Reducing %s subchannel allocation from %d to %d subchannels to fit into resource pool.',rmc,transmission.SubchannelAllocation(2),pool.MaxNumSubchannel);
        transmission.SubchannelAllocation(2) = pool.MaxNumSubchannels;
   end

   % Cross-check all the above field settings
   transmission = expandTransmissionParameters(pool,transmission);

   varargout = {transmission,pool,testconfig};  % RMC transmission config, Pool config, Test scenario parameters 

end

function [transmission,exa] = expandTransmissionParameters(pool,transmission)
    arguments
        pool                            % Already good
        transmission struct = struct()  % Initialize to an empty structure if not supplied, the code below will fill out missing fields
    end

    % Validate and complete the transmission config structure and cross-validate 
    % with the pool parameters.
    try
        % Use name-value argument validation for function arguments 
        % to validate and complete the 'transmission' parameter structure

        % First turn the transmission parameter structure into a cell array of 
        % name-value pairs, then pass this on to a second function which uses
        % name-value argument validation to validate and complete the structure.
        % This function will also cross-validate against the pool config state
        tnv = namedargs2cell(transmission);
        transmission = prepareTransmissionParameters(pool,tnv{:});
    catch me
        
        % Some information for further error message text reworking

        % class(me)
        % me.ArgumentName
        % me.ArgumentPosition
        
        % Exception type - 'matlab.internal.validation.RuntimePositionalException'...
        % This will only come from the first fixed position input, the 'pool'
        % class(me) = 'matlab.internal.validation.RuntimePositionalException'
        % with me.ArgumentPosition = 1, and ArgumentName as used in the call above (i.e. 'pool')
       
        % Exception type - 'matlab.internal.validation.RuntimeNameValueException'...
        % This will come from the 'transmission' structure, expanded into the name value list 
        % class(me) = 'matlab.internal.validation.RuntimeNameValueException'
        % with the name and position being relative to the NV definition block
        % The name being input has to match the NV name, by definition

        rethrow(me);

    end

    % Number of symbols reserved for PSFCH candidates within this slot
    psfchreservedsymbols = 3*( (pool.sl_PSFCH_Period_r16>0) && (mod(pool.SCSCarrier.NSlot,pool.sl_PSFCH_Period_r16)==0));

    sidelinksymbols = pool.sl_StartSymbol_r16+1 : pool.sl_LengthSymbols_r16-2-psfchreservedsymbols;         % Sidelink symbols available for transmission (no repetition or guard symbols)
    % Frequency, CRB/RB of first usable subchannel

    bwpstart = getWorkingBWPDims(pool);
    firstsubchannelCRB = bwpstart + pool.sl_StartRB_Subchannel_r16;
    firstsubchannelRB = firstsubchannelCRB-pool.SCSCarrier.NStartGrid;  % First RB of PSSCH (and PSCCH), relative to full SCS carrier resource grid
    
    % Combine subchannel(s) of interest with time/frequency pool dimensions to create linear (RE) indices
    % RB offset (relative to first RB of pool) of first subchannel
    subchannel = transmission.SubchannelAllocation(1);
    subchannelRBoffset = subchannel*pool.sl_SubchannelSize_r16;
    
    % First RE in first and last RB of the PSCCH
    firstrbre = 12*(firstsubchannelRB + subchannelRBoffset);        % First RE of the first PSCCH/PSSCH RB
    lastrbre = firstrbre + 12*(pool.sl_FreqResourcePSCCH_r16 - 1);  % First RE of the last PSCCH RB

    % Initial dependent calculations of the time/frequency allocation aspects
    exa.sidelinksymbols = sidelinksymbols;          % Time part of PSSCH (sidelink symbol indices, 0-based, core PSSCH part only, no AGC or guard)
    exa.firstrbre = firstrbre;                      % Frequency part - lb (inclusive)
    exa.lastrbre = lastrbre;                        % Frequency part - ub (inclusive)
    
    % Further possible augmentation:
    % exa.firstsubchannelCRB = firstsubchannelCRB;    % CRB of start of first subchannel of pool
    % exa.subchannelRBoffset = subchannelRBoffset;    % RB offset of first subchannel of transmission from subchannel of pool

end

% Define PSSCH transmission parameters
% The only one which relates to the (associated) PSCCH  
function slp = prepareTransmissionParameters(pool,slp)
       % Notes on the use of the syntatic machinery here:
       % See Name-value arguments under function argument validation
        arguments
            pool NRSidelinkResourcePool {validateConfig(pool)}     %#ok<INUSA>  
            slp.SubchannelAllocation {mustBeInteger, mustBeNonnegative, mustBeValidPSSCHAlloc(slp.SubchannelAllocation,pool)} = [0 1];   % Dynamic, SCI1 signalled [nstartsubCH0 LsubCH]
            slp.NumLayers(1,1) {mustBeMember(slp.NumLayers,[1 2])} = 1;                            % Dynamic, SCI1 signalled number of layers
            slp.Modulation {mustBeTextScalar, mustBeMember(slp.Modulation,["QPSK" "16QAM" "64QAM" "256QAM"])} = "QPSK";  % Dynamic, SCI1 signalled MCS
            slp.NumDMRSPositions(1,1) {mustBeMember(slp.NumDMRSPositions,[1 2 3 4])} = 4;          % Number of PSSCH DM-RS symbols in transmission
            slp.NumDMRSPositionsList(1,:) {mustBeMember(slp.NumDMRSPositionsList,[1 2 3 4]) } = [];% List of numbers of PSSCH DM-RS symbols configured by RRC 
            slp.TargetCodeRate(1,1) {mustBeInRange(slp.TargetCodeRate,0,1,'exclusive')} = 308/1024;% Dynamic, PSSCH code rate from the MCS field of the associated SCI1 (120/1024 ... 948/1024)
            slp.BetaSCI2Offset(1,1) {mustBeInRange(slp.BetaSCI2Offset,1.125,20)} = 3.5;            % Dynamic, selected via SCI1 from an L3 configured list (configured with indices 0...31, which indexes a beta offset table (the indexed table (TS 38.213 table 9.3-2 - CSI betas) values run 1.125...20))
            slp.OSCI2(1,1) {mustBeNonnegative, mustBeInteger} = 35;                                % Semi-static, number of bits in the configured SCI format 2-x message being sent/received
            slp.NXID {mustBeScalarOrEmpty,mustBeInteger} = [];                                     % Decimal representation of PSCCH control CRC (SCI1), used to override the associated PSSCH scrambling and PSSCH DM-RS (both SCI2/SL-SCH parts)
            slp.RedundancyVersion(1,1) {mustBeMember(slp.RedundancyVersion,[0 1 2 3])} = 0;        % RV for transmission (comes on SCI2)
            slp.HARQProcessID(1,1) {mustBeInteger,mustBeInRange(slp.HARQProcessID,0,15)} = 0;      % HARQ process ID for transmission (comes on SCI2)
            slp.PSFCHOverhead(1,1) {mustBeMember(slp.PSFCHOverhead,[0 1])} = 0;                    % PSFCH overhead indication (comes on SCI1)
            slp.OSCI1(1,1) {mustBeNonnegative, mustBeInteger} = 26;                                % Semi-static, number of bits in the configured SCI format 1A message being sent/received
        end

        % Any failures as a result of the _above_ argument definition block will _not_ be
        % caught below but will propagate directly up to the caller before any of the following code is run
        try 
            % Place any further preparatory code here
        catch me %#ok<UNRCH>
            rethrow(me);
        end

end


% Check the PSSCH subchannel allocation (format = [start,length]) against the pool configuration 
function mustBeValidPSSCHAlloc(s,pool)
    if length(s) ~= 2
        error('Subchannel allocation must have 2 elements ([start idx, length]).');
    end
    if s(2) < 1
        error('Subchannel allocation length part (%d) must be positive.',s(2));
    end
    if sum(s) > pool.sl_NumSubchannel_r16
        error('Subchannel allocation ([start idx=%d, length=%d]) exceeds the number of subchannels available in the pool (%d).',s(1),s(2),pool.sl_NumSubchannel_r16);
    end
end


% PSCCH (control) resourcing
function [slo, miselect] = getPSCCHResources(slpp,trans,slo)

    if nargin < 3
        slo = struct();
    end

    [~,exa] = expandTransmissionParameters(slpp,trans);  % Don't need the transmission parameters back out, just the initial dependent calculations

    sidelinksymbols = exa.sidelinksymbols ;          % Time part of PSSCH (sidelink symbols indices, 0-based, core PSSCH part only, no AGC or guard)
    firstrbre = exa.firstrbre;                       % Frequency part - lb,
    lastrbre = exa.lastrbre;                         % Frequency part - ub

    % Control data/DM-RS RE indices in each symbol
    % 
    % Generally, in terms of units of preference (RB or RE),
    % DM-RS prefers RE for the continuous striding
    % DATA prefers 12*RB for the RE offsetting (non-continuous striding in a PRB)

    % RE indices for each PSCCH symbol
    controldmrs = (firstrbre+1 : 4 : lastrbre+12-1)';    % DM-RS uniform stride across the PSCCH resource blocks (3 DM-RS RE per RB), 1,5,9...
    controldata = reshape( (firstrbre : 12 : lastrbre) + [0  2 3 4  6 7 8  10 11]',[],1);  % Net resources left after DM-RS (9 control data RE per RB)
    
    % Now expand RE indices across allocation symbols, to give linear indices into resource grid  (implicit expansion of [s0,s1,s2...] + [re0,re1,re2...]')
    symbolindices = 12*slpp.SCSCarrier.NSizeGrid*sidelinksymbols(1:slpp.sl_TimeResourcePSCCH_r16);
    allcdindices = reshape(symbolindices + controldmrs,[],1);
    allcindices = reshape(symbolindices + controldata,[],1);
    
    % PSCCH DM-RS symbols
    % Need 6 bits per CRB (3 QPSK symbols per CRB)
    nslotsymb = slpp.SCSCarrier.SymbolsPerSlot;
    nslot = slpp.SCSCarrier.NSlot;
    cinit = @(nid,nsym) mod(2^17*(nslotsymb*nslot + nsym + 1)*(2*nid + 1) + 2*nid,2^31);
    dmrsnid = slpp.sl_DMRS_ScrambleID_r16; % sl-DMRS-ScrambleID;
    SymCD = arrayfun(@(nsym)nrPRBS(cinit(dmrsnid,nsym),2*3*[slpp.SCSCarrier.NStartGrid+firstrbre/12, slpp.sl_FreqResourcePSCCH_r16])',...
                     sidelinksymbols(1:slpp.sl_TimeResourcePSCCH_r16),...
                       'UniformOutput',false);
    % Extract PRBS values associated with PRB and turn into complex DM-RS symbols
    bpsk = 1/sqrt(2)*(1-2*reshape([SymCD{:}],2,[]).');
    dmrsCD = complex(bpsk(:,1),bpsk(:,2));
    
    % Apply one of the (randomly) selected complex phase shift sequences
    % 
    % Requirement to select, and to get the selected index/version back out to the surface
    % But difference between transmit runtime procedures and receive runtime procedures, and deterministic procedural aspects and random procedural aspects
    % 
    miselect = 0;  % i is one of {0,1,2} - for random selection use randi([0 2])
    masks = [1        1                1;        % Each mask is a column in this array, expanded across frequency
             1 exp(1i*2/3*pi)  exp(-1i*2/3*pi);
             1 exp(-1i*2/3*pi) exp(1i*2/3*pi)];
    mseq = repmat(masks(:,miselect+1),length(dmrsCD)/3,1); % Expand the selected mask value matrix so that it will cover all RE in frequency
    dmrsCD = mseq.*dmrsCD;  % Single port so this will be column for the miselect
       
    % PSCCH (SCI1)
    % Indices and DM-RS
    slo.PSCCHIndices = allcindices;
    slo.PSCCHDMRSIndices = allcdindices;
    slo.PSCCHDMRS = dmrsCD;
    % Bit/symbol capacity of channel, as seen at the input to the PSCCH
    slo.PSCCHGd = numel(allcindices);   % Number of symbols/resource elements available
    slo.PSCCHG = 2*slo.PSCCHGd;         % QPSK on a single layer

end


% PSSCH (data) resourcing
function slo = getPSSCHResources(slpp,slpt,slo)
    
    if nargin < 3
        slo = struct();
    end

    [slpt,exa] = expandTransmissionParameters(slpp,slpt);

    sidelinksymbols = exa.sidelinksymbols ;          % Time part of PSSCH (sidelink symbols indices, 0-based, core PSSCH part only, no AGC or guard)
    firstrbre = exa.firstrbre;                       % Frequency part - lb,
    lastrbre = exa.lastrbre;                         % Frequency part - ub

    % Get the DM-RS symbol indices (ordered, 0-based, relative to the formal sidelink start symbol)
    ld = length(sidelinksymbols)+1;   % DM-RS ld duration for table lookup should include initial duplicate symbol (but not the trailing guard)
    dmrssymbols = lookupPSSCHDMRSSymbols(ld,slpp.sl_TimeResourcePSCCH_r16,slpt.NumDMRSPositions(1));   % Indices in DM-RS returned are 0-based, relative to scheduled sidelink resources, inc. duplicate
    dmrssymbols = dmrssymbols-1;  % Now adjust DM-RS locations from the table so that they don't account for initial duplicate symbol
    if isempty(dmrssymbols)
        warning('No PSSCH DM-RS symbols defined for this PSSCH configuration.');
    end
    
    % Port offsets into entire slot resource array
    numslotresources = 12*slpp.SCSCarrier.NSizeGrid*slpp.SCSCarrier.SymbolsPerSlot; % Size of slot resource element grid
    portoffsets = numslotresources*(0:slpt.NumLayers-1);
    
    % PSSCH PRB start for each OFDM symbol
    allocrbrestart = firstrbre*ones(size(sidelinksymbols));                              % Initialize RB indices for set of SL symbols to be first RB of first subchannel
    allocrbrestart(1:min(slpp.sl_TimeResourcePSCCH_r16,length(allocrbrestart))) = lastrbre+12;  % Now adjust the PRB start in symbols carrying PSCCH in the first subchannel
    
    % Data RE strides in each OFDM symbol
    restride = ones(size(sidelinksymbols)); % Data RE stride for non DM-RS symbols
    restride(dmrssymbols+1) = 2;            % Data RE stride for DM-RS symbols - Type 1 DM-RS config; 6 DM-RS in a PRB, running 1,3,... (constant stride of 2 PRB)

    % Last RE in all the PSSCH allocation symbols
    lastre = firstrbre + (12*slpt.SubchannelAllocation(2)*slpp.sl_SubchannelSize_r16)-1;

    % Calculate the grid indices for the PSSCH resource elements
    % - Range is first RE of PSSCH in allocation symbol : stride : last RE of entire PSSCH allocation
    % - First RE in a symbol will account for presence of PSCCH in that symbol
    % - Stride for that symbol is 1 or 2, depending on whether DM-RS is present in that symbol
    % - Offset the entire range with grid oriented linear offset for that associated symbol

    % Create the RE indices associated with each symbol (each cell contains the linearized indices for a symbol)
    Ure = arrayfun(@(o,x,s)o+x:s:o+lastre,...   % Inclusive RE range with the : operator
                      12*slpp.SCSCarrier.NSizeGrid*sidelinksymbols,allocrbrestart,restride,...
                       'UniformOutput',false);   % Create sequences with varying strides
    CURe = [Ure{:}]';   % Now horizontally concatenate all the symbols into a single vector
    
    % Check whether DM-RS are not defined, therefore in full data 'test mode'
    if ~isempty(dmrssymbols)

        % The PSSCH 'split' symbol is the first DM-RS symbol with a non-zero number of elements
        symbolcaps = cellfun('length',Ure);
        dmrssymcaps = symbolcaps(dmrssymbols+1);
        ff = find(dmrssymcaps,1);
        sci2symbol1 = dmrssymbols(ff);
        
        % Separate into {indices *before* first DM-RS carrying symbol (dmrssymbols(1) value is 0-based already), indices *from* first DM-RS carrying symbol}
        CURe2 = {[Ure{1:sci2symbol1}]'  [Ure{sci2symbol1+1:end}]'};  % Remember DM-RS symbol index values are 0-based here (relative to sidelink part of slot)       
    
        % Compute Q'_SCI2 (before gamma) per TS 38.212 Sec 8.4.4
        qdsci2_1 = calculateQprimeSCI2(slpp,slpt);
        
        % Calculate the gamma value 
        lrb = fix(CURe2{2}(qdsci2_1:min(qdsci2_1+12,end),1)/12);  % Pick up a block of PSSCH indices starting in the DM-RS symbol and covering above symbol capacity plus 12, and label with a PRB indices
        gamma = find(lrb(1)~=lrb(2:end),1)-1;                     % RE remainer in whole RB
        qdsci2 = qdsci2_1+gamma;                                  % Note that, if considering DM-RS only (no PT-RS etc), this will be a multiple of 6
        
        msymbolSCI2 = qdsci2;   % This calculation is for a single layer - we just duplicate the SCI2 data across all PSSCH layers
    
        % Isolate the SCI2 and SL-SCH mapping indices
        % And also expand across ports/layers
        CURe3 = { portoffsets + CURe2{2}(1:msymbolSCI2), ...                        % SCI2 part
                  portoffsets + [CURe2{1}(1:end); CURe2{2}(msymbolSCI2+1:end)]};    % SL-SCH part
    else
        % If no DM-RS active then we are in 'test' mode
        % 
        % use the first x symbols for the SCI2
        % Isolate the SCI2 and SL-SCH mapping indices
        % And expand across ports/layers
    
        if ~isfield(slpt,'msymbolSCI2')
            warning('No DM-RS defined so in test mode. No explicit parameter (msymbolSCI2) defined to specify the number of SCI2 symbols therefore assuming no SCI2 part.');
            slpt.msymbolSCI2 = 0;
        end
        gamma = 0;
        % Expand both parts across the port/layer grid planes
        CURe3 = { portoffsets + CURe(1:slpt.msymbolSCI2), ...    % SCI2 part
                  portoffsets + CURe(slpt.msymbolSCI2+1:end)};   % SL-SCH part
    end
    
    % Combine the SCI2 and SL-SCH carrying indices into the complete PSSCH set
    CUReAll = vertcat(CURe3{:});
    
    % Create the DM-RS RE indices associated with each symbol (each cell contains the linearized indices for a symbol)
    % 6 DM-RS symbols per RB, starting with a 1 RE offset in the RB
    UreD = arrayfun(@(o,x)o+x+1:2:o+lastre,...   % Inclusive RE range with the : operator
                      12*slpp.SCSCarrier.NSizeGrid*sidelinksymbols(dmrssymbols+1),allocrbrestart(dmrssymbols+1),...
                       'UniformOutput',false);   % Create sequences with varying strides
    CUReD = [UreD{:}]';   % Now horizontally concatenate all the symbols into a single vector

    if ~isempty(CUReD)
        CUReD = portoffsets + CUReD;  % Expand DM-RS indices in a single plane across ports ([p0,p1] + [re0,re1,re2...]')
    end
    
    % PSSCH DM-RS
    nslotsymb = slpp.SCSCarrier.SymbolsPerSlot;
    nslot = slpp.SCSCarrier.NSlot;
    nid = 0;
    if ~isempty(slpt.NXID)
        nid = slpt.NXID;     % Used in the initialization of the PSSCH DM-RS (from PSCCH control CRC (SCI1))
    end

    % Type 1 DM-RS values
    % 12 bits required per RB (6 QPSK symbols per RB), there we can use the RE indices directly
    cinit = @(nid,nsym) mod(2^17*(nslotsymb*nslot + nsym + 1)*(2*nid + 1) + 2*nid,2^31);
    SymD = arrayfun(@(nsym,symrestart)nrPRBS(cinit(nid,nsym),[12*slpp.SCSCarrier.NStartGrid+symrestart, lastre+1-symrestart])',...
                     sidelinksymbols(dmrssymbols+1),allocrbrestart(dmrssymbols+1),...
                       'UniformOutput',false);
    % Extract PRBS values associated with PRB and turn into complex DM-RS symbols
    bpsk = 1/sqrt(2)*(1-2*reshape([SymD{:}],2,[]).');
    dmrs = complex(bpsk(:,1),bpsk(:,2));
    
    % Expand across ports
    % For layer 2, just multiply by a sequence of +1,-1
    mask = [1  1; 1 -1];
    fullmask = repmat(mask(:,1:slpt.NumLayers),length(dmrs)/2,1);
    dmrs = repmat(dmrs,1,slpt.NumLayers).*fullmask;
        
    % Calculate the PSSCH bit and symbol capacities from the set of indices
    gd = cellfun('prodofsize',CURe3);     % Number of resource elements associated the PSSCH ([SCI2  SL-SCH])
    bps = @(x)sum([1,2,4,6,8].*(upper(x)==["BPSK","QPSK","16QAM","64QAM","256QAM"])); % Bits per QAM symbol
    qm = bps(slpt.Modulation);
    obits = [2 qm].*gd;  % SCI2 is always QPSK
    
    % Bit capacity, for each signal component, as seen at the input to the PSSCH
    obits = obits./[slpt.NumLayers 1];  % Adjust for the layer symbol duplication of the SCI2

    % PSSCH (SC12 and SL-SCH parts)
    % Indices and DM-RS
    slo.PSSCHIndices = CUReAll;
    slo.PSSCHIndicesSplit = CURe3;
    slo.PSSCHDMRSIndices = CUReD;
    slo.PSSCHDMRS = dmrs;
    
    % PSCCH/PSSCH bit/symbols capacities
    slo.PSSCHGd = gd;  
    slo.PSSCHG = obits;    % Bit capacity of the PSSCH, split into [SCI2 SL-SCH] parts
    slo.Gamma = gamma;
end

%calculateQprimeSCI2 Compute Q'_SCI2 per TS 38.212 Section 8.4.4
%
%   [QprimeSCI2, N_PSSCH_symb] = calculateQprimeSCI2(poolCfg, txCfg)
%
%   This determines how many coded modulation symbols (QPSK) are allocated
%   to the 2nd-stage SCI on PSSCH, BEFORE adding the gamma correction.
%   The gamma correction (vacant REs to complete the last RB) is applied
%   by the caller after this function returns.
%
%   TS 38.212 V19 Section 8.4.4 formula:
%
%     Q'_SCI2 = min(qBeta, qAlpha)
%
%   where:
%     qBeta  = ceil( (O_SCI2 + L_SCI2) * beta^SCI2_offset / (Q^SCI2_m * R) )
%     qAlpha = floor( alpha * SUM_l( M^SCI2_sc(l) ) )
%
%   Term definitions (from spec):
%     O_SCI2         - Number of 2nd-stage SCI information bits
%     L_SCI2         - CRC length = 24 bits (CRC24C)
%     beta^SCI2_offset - Beta offset from SCI 1-A "Beta_offset indicator"
%     Q^SCI2_m       - Modulation order for SCI2 = 2 (QPSK, always)
%     R              - Code rate from SCI 1-A "MCS" field
%     alpha          - Higher-layer parameter sl-Scaling (controls max
%                      fraction of PSSCH REs usable for SCI2)
%     M^SCI2_sc(l)   - Available SCI2 subcarriers in OFDM symbol l
%                      = M^PSSCH_sc(l) - M^PSCCH_sc(l)
%                      where M^PSSCH_sc = n_PRB * 12 (allocated PRBs as
%                      subcarriers) and M^PSCCH_sc = PSCCH + PSCCH-DMRS
%                      subcarriers in symbols that overlap with PSCCH
%
%   After this function, the caller adds gamma:
%     Q'_SCI2_final = Q'_SCI2 + gamma
%     G^SCI2        = Q'_SCI2_final * Q^SCI2_m    (capped at 4096)
%
%   Inputs:
%     poolCfg (slpp) - Resource pool parameters:
%       .sl_Scaling_r16           - alpha (sl-Scaling, 0..1)
%       .sl_SubchannelSize_r16    - PRBs per subchannel
%       .sl_LengthSymbols_r16     - Total sidelink symbols (incl. guard)
%       .sl_PSFCH_Period_r16      - PSFCH period (0,1,2,4)
%       .sl_FreqResourcePSCCH_r16 - PSCCH frequency PRBs
%       .sl_TimeResourcePSCCH_r16 - PSCCH time symbols (2 or 3)
%
%     txCfg (slpt) - Transmission parameters:
%       .OSCI2                    - O_SCI2 (SCI2 payload bits)
%       .BetaSCI2Offset           - beta^SCI2_offset value
%       .TargetCodeRate           - R (code rate from MCS)
%       .SubchannelAllocation     - [startSubCh, numSubCh]
%       .PSFCHOverhead            - PSFCH overhead indication (from SCI 1-A)
%
%   Outputs:
%     QprimeSCI2   - Q'_SCI2 (before gamma), number of QPSK symbols
%     N_PSSCH_symb - Number of PSSCH OFDM symbols (N^PSSCH_symbol)
%
%   See also: SCIGenerator.calculateSCI2RateMatch (equivalent computation
%   using different input format)

function [QprimeSCI2, N_PSSCH_symb] = calculateQprimeSCI2(poolCfg, txCfg)

    % --- Extract parameters ---
    O_SCI2    = txCfg.OSCI2;                  % SCI2 payload size (bits)
    L_SCI2    = 24;                           % CRC24C length
    beta      = txCfg.BetaSCI2Offset;         % beta^SCI2_offset
    R         = txCfg.TargetCodeRate;          % Code rate from MCS
    alpha     = poolCfg.sl_Scaling_r16;        % sl-Scaling (0..1)
    Q_SCI2_m  = 2;                            % SCI2 modulation order (QPSK, always)

    % --- Number of PSSCH OFDM symbols: N^PSSCH_symbol ---
    % N^sh_symb = sl-LengthSymbols - 2  (subtract guard + AGC symbols)
    % N^PSFCH_symb: 3 if PSFCH is present in this slot, 0 otherwise
    %   - Period=0: no PSFCH → N^PSFCH_symb = 0
    %   - Period=1: PSFCH every slot → N^PSFCH_symb = 3
    %   - Period=2,4: PSFCH if "PSFCH overhead indication"=1 → N^PSFCH_symb = 3
    hasPSFCH = (poolCfg.sl_PSFCH_Period_r16 == 1) || ...
               (poolCfg.sl_PSFCH_Period_r16 > 1 && txCfg.PSFCHOverhead ~= 0);
    N_PSFCH_symb = 3 * hasPSFCH;
    N_PSSCH_symb = poolCfg.sl_LengthSymbols_r16 - 2 - N_PSFCH_symb;

    % --- Compute SUM_l M^SCI2_sc(l) ---
    % M^PSSCH_sc(l) = allocated PRBs * 12 subcarriers/PRB, summed over
    %                 N^PSSCH_symbol OFDM symbols
    numAllocPRBs     = txCfg.SubchannelAllocation(2) * poolCfg.sl_SubchannelSize_r16;
    sumM_PSSCH       = 12 * numAllocPRBs * N_PSSCH_symb;

    % M^PSCCH_sc(l) = PSCCH PRBs * 12, summed over PSCCH time symbols
    %                 (only in symbols where PSCCH overlaps with PSSCH)
    numPSCCH_PRBs    = poolCfg.sl_FreqResourcePSCCH_r16;
    numPSCCH_symbols = poolCfg.sl_TimeResourcePSCCH_r16;
    sumM_PSCCH       = 12 * numPSCCH_PRBs * numPSCCH_symbols;

    % Total available SCI2 subcarriers across all PSSCH symbols
    sumM_SCI2 = sumM_PSSCH - sumM_PSCCH;

    % --- Q'_SCI2 formula (TS 38.212 Sec 8.4.4) ---
    % Term 1: beta-offset driven (how many symbols needed given SCI2 size)
    qBeta  = ceil((O_SCI2 + L_SCI2) * beta / (Q_SCI2_m * R));

    % Term 2: alpha-scaled capacity limit (max fraction of PSSCH for SCI2)
    % [FIX] Spec says floor(), was incorrectly using ceil()
    qAlpha = floor(alpha * sumM_SCI2);

    % Q'_SCI2 = min of the two terms
    % Note: gamma is added by the caller (lines 882-884 in getPSSCHResources)
    QprimeSCI2 = min(qBeta, qAlpha);

end


% Get the PSSCH DM-RS symbol indices, relative to start of the sidelink portion 
function dmrssymbolset = lookupPSSCHDMRSSymbols(nsymbols,pscchduration,numdmrspos)

    % The symbols returned from the table are relative to the start of the sidelink portion of the slot already
    % Comments on DM-RS placement:
    % - Duration (used in the DM-RS position tables), includes the duplicated OFDM symbol (but not the trailing guard symbol)
    % - So the 'duration' is the duration of active PSSCH symbols
    % - The L3 signalled start/length includes duplicated and guard, it's the 'period' in the SL slot associated with SL in the BWP 
    % - Note that duplicated symbol is NOT included in the definition of the 'PSSCH resource allocation' i.e. the mapping 

    % lbar (tables below) are the PSSCH DM-RS positions, defined relative to the start of the sidelink part
    %
    % Create static table for PSSCH DM-RS time-domain locations (TS 38.211 Table 8.4.1.1.2-1)
    persistent dmrs_pos;
    if isempty(dmrs_pos)

        % PSSCH DM-RS time-domain locations
        % These location values are relative to the very start of the SL allocation 
        % TS 38.211 Table 8.4.1.1.2-1
        dmrs_2pdcchsymbols = {
          % 2 dmrs  3 dmrs   4 dmrs
            [],     [],      [];         %  1 symbol duration (Duration does not include guard, but includes leading duplicate symbol)
            [],     [],      [];         %  2 symbol duration
            [],     [],      [];         %  3 symbol duration
            [],     [],      [];         %  4 symbol duration
            [],     [],      [];         %  5 symbol duration
            [1,5],  [],      [];         %  6 symbol duration (A total 7 of symbols is the minimum sidelink length in a slot, ENUMERATED {sym7, sym8, sym9, sym10, sym11, sym12, sym13, sym14} values)
            [1,5],  [],      [];         %  7 symbol duration
            [1,5],  [],      [];         %  8 symbol duration
            [3,8],  [1,4,7], [];         %  9 symbol duration
            [3,8],  [1,4,7], [];         % 10 symbol duration
            [3,10], [1,5,9], [1,4,7,10]; % 11 symbol duration
            [3,10], [1,5,9], [1,4,7,10]; % 12 symbol duration
            [3,10], [1,6,11],[1,4,7,10]; % 13 symbol duration
        };

        dmrs_3pdcchsymbols = {
          % 2 dmrs  3 dmrs   4 dmrs
            [],     [],      [];         %  1 symbol duration (duration includes leading duplicate symbol)
            [],     [],      [];         %  2 symbol duration
            [],     [],      [];         %  3 symbol duration
            [],     [],      [];         %  4 symbol duration
            [],     [],      [];         %  5 symbol duration
            [1,5],  [],      [];         %  6 symbol duration
            [1,5],  [],      [];         %  7 symbol duration
            [1,5],  [],      [];         %  8 symbol duration
            [4,8],  [1,4,7], [];         %  9 symbol duration
            [4,8],  [1,4,7], [];         % 10 symbol duration
            [4,10], [1,5,9], [1,4,7,10]; % 11 symbol duration
            [4,10], [1,5,9], [1,4,7,10]; % 12 symbol duration
            [4,10], [1,6,11],[1,4,7,10]; % 13 symbol duration
        };

        % Combined sub-tables into single cell array container
        dmrs_pos = {dmrs_2pdcchsymbols, dmrs_3pdcchsymbols};
    end

    % Look up relevant sub-table from the set, dependent on the PSCCH duration
    positionstable = dmrs_pos{1+(pscchduration>2)};

    % Get the duration dependent symbol DM-RS position information
    posidx = numdmrspos-1;  % First column of the table is for 2 DM-RS symbols
    if posidx > 0 && posidx <= size(positionstable,2) && nsymbols
        
        % Find first non-empty set, starting from number of PSSCH DM-RS specified 
        posforlength = positionstable(nsymbols,:);
        choices = cellfun('length',posforlength);
        selectednumpos = min(max(choices),numdmrspos);
        
        dmrssymbolset = positionstable{nsymbols,selectednumpos-1};
    else
        dmrssymbolset = [];
    end

end


% Physical channel processing for both PSCCH and PSSCH, given 
function [ccsymbols,symbols] = physicalcodeup(slp,controlbits,controlpartbits,datapartbits)

    % PSCCH scrambling
    clen = length(controlbits);
    cinit = 1010;
    scbits = nrPRBS(cinit,clen);
    csdata = xor(controlbits,scbits);
    % PSCCH modulation
    ccsymbols = nrSymbolModulate(csdata,'QPSK');
  
    % PSSCH scrambling (TS 38.211 Section 8.3.1.1)
    % Separate control and data parts for PSSCH (or demultiplexed, if considered together before separation)
    
    % Scrambling sequence generator initialization for PSSCH parts
    cinit = 2^15*(mod(slp.NXID,2^16))+1010; % (NIDX is the decimal SCI1 CRC on PSCCH)
    
    % Separated data and control parts
    %
    % How the scrambling section operation is defined and works:
    % - The input parts (SCI2 and data) are already multiplexed, and placeholder pairs inserted for symbol duplication if 2 layers
    % - Both parts are scrambled with the same PRBS sequence
    % - For this operation, any placeholders in the SCI2 part are not scrambled but are replaced with repeated scrambled QPSK symbols
    % - The data part is scrambled as per usual
    % 
    % How the modulation section works:
    % - Separate modulation for the SCI2 and data parts
    % - SCI2 is always QPSK
    % - Data part can be QPSK, 16QAM, 64QAM or 256QAM
    % 
    % How the layering and precoding sections work
    % - Layering is according to 1 or 2 layers
    % - Precoding is identity
    
    % Scrambling
    clen = max(numel(controlpartbits),numel(datapartbits));
    sbits = nrPRBS(cinit,clen);
    
    % SCI2 control part
    % Placeholder bits, for multi-layer transmission
    % Repeat previous symbol's output (scrambled) bit, and don't advance scrambling
    
    % Placeholder pair insertion
    controlpart = reshape([reshape(controlpartbits,2,[]);-1*ones(2*(slp.NumLayers-1),length(controlpartbits)/2)],[],1);   % Expand with placeholder bit pairs
    
    % Scramble non-placeholders
    npb = (controlpart >= 0);            % Non-placeholder bits
    scontrol = zeros(size(controlpart)); % Could write directly into control
    scontrol(npb) = xor(controlpart(npb),sbits(1:nnz(npb)));
    
    % Repeat scrambled bits for the placeholder
    pb = find(~npb);                 % Placeholder bits
    scontrol(pb) = scontrol(pb-2);   % Repeat previous symbol's bit for the PB
    
    % As an alternative to placeholder replacement... just duplicate pairs of scrambled bits 
    % or even just duplicate the QPSK symbols themselves
    % scontrol = reshape(repmat(scontrol',nlayers,1),[],1);   % Duplicate each scrambled bit
    
    % Scramble data part 
    sdata = xor(datapartbits,sbits(1:numel(datapartbits)));
    
    % Modulation
    % QPSK Control, QAM Data (QPSK,16QAM,64QAM,256QAM)
    csymbols = nrSymbolModulate(scontrol,'QPSK');           % Modulate SCI2 part
    dsymbols = nrSymbolModulate(sdata,slp.Modulation);      % Modulate SL-SCH part
    symbols = [csymbols;dsymbols];                          % Combine both SCI2 and SL-SCH parts
    
    % Layering
    symbols = nrLayerMap(symbols,slp.NumLayers);              % Layer combined PSSCH data

end

function [sciCW,crc] = sciEncode(sciBits,E,sci2)
%nrSCIEncode Sidelink control information encoding
%   [SCICW,MCRC] = nrSCIEncode(SCIBITS,E,SCI2) encodes the input SCI bits,
%   SCIBITS, as per TS 38.212 Sections 7.3.2, 7.3.3 and 7.3.4 to output the
%   rate-matched coded block, SCICW, of specified length E. The processing
%   includes CRC attachment, polar coding and rate matching.
%   The input SCIBITS must be a binary column vector corresponding to the
%   SCI bits and the output is a binary column vector of length E. SCI2 
%   flags whether SCI2 or SCI1 encoding.

    if nargin < 3
        sci2 = 0;  % Default to SCI1 encoding
    end
    
    Ibil = logical(sci2); % SCI2

    % Check sci info length, 36-24 bits min

    % CRC attachment, TS 38.212 section 7.3.2
    rnti = 0;
    bitscrcPad = nrCRCEncode([ones(24,1,class(sciBits)); sciBits],'24C',rnti);  % prepend 1s
    cVec = bitscrcPad(25:end,1);            % remove 1s

    % Turn CRC bits into a decimal representation
    crc = sum((2.^(23:-1:0)').*logical(cVec(end-23:end,1)));

    % Channel coding, TS 38.212 section 7.3.3
    encOut = nrPolarEncode(cVec,E);

    % Rate matching, TS 38.212 section 7.3.4 or 8.4.4 (I_BIL = 1 for SCI2)
    K = length(cVec);
    sciCW = nrRateMatchPolar(encOut,K,E,Ibil);

end

function [sciBits,mask,crc] = sciDecode(sciCW,Kout,L,sci2)
%nrSCIDecode Sidelink control information decoding
%   [SCIBITS,MASK,MCRC] = nrSCIDecode(SCICW,K,L) decodes the input soft bits, SCICW, as
%   per TS 38.212 Sections 7.3.4, 7.3.3 and 7.3.2 to output the decoded SCI
%   bits, SCIBITS of length K. The processing includes rate recovery, polar
%   decoding and CRC decoding.
%   L is the specified list length used for polar decoding.
%   The input SCICW must be a column vector of soft bits (LLRs) and the
%   output SCIBITS is the output SCI message of length K. SCI2 flags 
%   whether SCI2 or SCI1 decoding.
%   MASK equals the RNTI value for no CRC error for the decoded block.

    if nargin < 4
        sci2 = 0;  % Default to SCI1 decoding
    end

    Ibil = logical(sci2); % SCI2
    rnti = 0;

    E = length(sciCW);
    K = Kout+24;            % K includes CRC bits
    nMax = 9;               % for downlink ... but for SCI2??
    N = nr5g.internal.polar.getN(K,E,nMax);

    % Rate recovery, Section 7.3.4, [1]
    recBlk = nrRateRecoverPolar(sciCW,K,N,Ibil);

    % Polar decoding, Section 7.3.3, [1]
    padCRC = true;              % signifies input prepadding with ones
    decBlk = nrPolarDecode(recBlk,K,E,L,padCRC,rnti);

    % CRC decoding, Section 7.3.2, [1]
    [padSCIBits,mask] = nrCRCDecode([ones(24,1);decBlk],'24C',rnti);
    sciBits = cast(padSCIBits(25:end,1),'int8'); % remove the prepadding

    % Turn CRC bits into a decimal representation
    crc = sum((2.^(23:-1:0)').*logical(decBlk(end-23:end,1)));

end

% Decode PSCCH/PSSCH physical channels and transport channel/control coding
function [eset,sld,slo] = receiveInPool(pool,transmission,baseband,slschrx,decalgo)
    
    nsci1infobits = transmission.OSCI1;
    nsci2infobits = transmission.OSCI2;

    % Demodulate received baseband IQ waveform
    grid = nrOFDMDemodulate(pool.SCSCarrier,baseband);
    
    % --- PSCCH decoding ---

    % Get the PSCCH transmission resources
    sloc = getPSCCHResources(pool,transmission);

    % Extract PSCCH symbols from mapped resource elements
    % Channel estimate using PSCCH DM-RS and then equalize PSCCH
    [cresymbols,csi,nVarC] = exqualize(pool.SCSCarrier,grid,'PSCCH',sloc,decalgo);
    
    % Now assume that single port PSCCH was transmitted on the first plane of transmission resource array
    rdsbitsSCI1 = nrSymbolDemodulate(cresymbols(:,1),'QPSK',nVarC);
    
    % PSCCH Scrambling
    clen = length(rdsbitsSCI1);
    cinit = 1010;
    scbits = nrPRBS(cinit,clen,"MappingType","signed");
    rdsbitsSCI1 = rdsbitsSCI1 .* scbits;  % Descramble SCI1 part
    % Scale LLR by CSI
    qm = 2;  % Always QPSK for PSCCH
    csi = repmat(csi(:,1).',qm,1);            % Expand CSI by each bit per symbol - repeat CSI as row then serialize into a column
    rdsbitsSCI1 = rdsbitsSCI1 .* csi(:);      % Scale LLR by CSI
    
    % Other side of the rate matching, therefore requires knowledge of length of SCI1
    [sci1infobits,mask1,nxid] = sciDecode(rdsbitsSCI1,nsci1infobits,8,0);
    eset.SCI1 = logical(mask1);

    % If an NXID override value was not set then use the PSCCH CRC NXID value
    if isempty(transmission.NXID)
        transmission.NXID = nxid;
    end

    % --- PSSCH decoding (SCI2 and SL-SCH parts) ---

    % Get the PSSCH transmission resources
    slo = getPSSCHResources(pool,transmission);

    % Extract PSSCH symbols from mapped resource elements
    % Channel estimate using PSSCH DM-RS and then equalize PSSCH
    [resymbols,csi,nVarD] = exqualize(pool.SCSCarrier,grid,'PSSCH',slo,decalgo);

    % CSI will be for all layers
    csi = nrLayerDemap(csi);
    csi = csi{1}; % Only one codeword

    % Undo the layer mapping into a single vector
    rdsymbols = nrLayerDemap(resymbols);
    rdsymbols = rdsymbols{1};  % Only one codeword
    
    % Demodulate into soft bits, and descramble
    
    % Scrambling sequence generator initialization for PSSCH parts
    cinit = 2^15*(mod(transmission.NXID,2^16))+1010; % (NIDX is the decimal SCI1 CRC on PSCCH)
    % Scrambling sequence
    clen = max(slo.PSSCHG);
    sbits = nrPRBS(cinit,clen,"MappingType","signed");
    
    % PSSCH - SCI2 PART
    % Total number of QPSK symbols across all layers    
    nsymSCI2 = (slo.PSSCHG(1)/2)*transmission.NumLayers;  % Number of received Or numel(slo.PSSCHIndicesSplit{1});
    rdsbitsSCI2 = nrSymbolDemodulate(rdsymbols(1:nsymSCI2),'QPSK',nVarD);
    
    % Apply associated CSI symbol weighting to LLR soft bits
    % 
    % Scale LLR by CSI
    qm = 2;  % QPSK
    csisci2 = repmat(csi(1:nsymSCI2).',qm,1);     % Expand by each bit per symbol, repeat CSI as row then serialize into a column
    rdsbitsSCI2 = rdsbitsSCI2 .* csisci2(:);      % Scale LLR by CSI
    
    % Soft combining of SCI2 repetition, in the case of 2 layers
    if transmission.NumLayers > 1
        rdsbitsSCI2 = reshape(rdsbitsSCI2,4,[]);    % Pair up QPSK tuples in a each row
        rdsbitsSCI2 = reshape(rdsbitsSCI2(1:2,:) + rdsbitsSCI2(3:4,:),[],1);  % Combine the replicated (soft) bits
    end
    rdsbitsSCI2 = rdsbitsSCI2 .* sbits(1:length(rdsbitsSCI2));  % Descramble SCI2 part
    
    % Other side of the rate matching, therefore require knowledge of length of SCI2
    [sci2infobits,mask2] = sciDecode(rdsbitsSCI2,nsci2infobits,8,1);  % L=8 is the decoder list length
    eset.SCI2 = logical(mask2);

    % PSSCH - SL-SCH PART
    rdsbitsSLSCH = nrSymbolDemodulate(rdsymbols(nsymSCI2+1:end),transmission.Modulation,nVarD);  % Demodulate SL-SCH data part
    % Scale LLR by CSI
    qm = length(rdsbitsSLSCH)/(length(rdsymbols)-nsymSCI2);         % Bits per QAM symbol
    csislsch = repmat(csi(nsymSCI2+1:end).',qm,1);                  % Expand by each bit per symbol, repeat CSI as row then serialize into a column
    rdsbitsSLSCH = rdsbitsSLSCH .* csislsch(:);                     % Scale LLR by CSI
    
    rdsbitsSLSCH = rdsbitsSLSCH .* sbits(1:length(rdsbitsSLSCH));   % Descramble SL-SCH data part    
    
    if isfield(decalgo,'DecodeSLSCH') && decalgo.DecodeSLSCH
        %   TRBLKOUT = step(DLSCHDEC,RXSOFTBITS,MODULATION,NLAYERS,RV), and
        %   TRBLKOUT = step(DLSCHDEC,RXSOFTBITS,MODULATION,NLAYERS,RV,HARQID)
        if slschrx.MultipleHARQProcesses
            [slschinfobits,blkerr] = slschrx.step(rdsbitsSLSCH,transmission.Modulation,transmission.NumLayers,transmission.RedundancyVersion,transmission.HARQProcessID);
        else
            [slschinfobits,blkerr] = slschrx.step(rdsbitsSLSCH,transmission.Modulation,transmission.NumLayers,transmission.RedundancyVersion);
        end
    else
        slschinfobits = [];
        blkerr = 0;
    end

    eset.SLSCH = logical(blkerr);
 
    % External data processing access - intermediate processed data points
    sld = struct();

    % Data and control information bits (input to the coding - 38.211)
    sld.SCI1Bits = sci1infobits;            % SCI1 information bits for PSCCH
    sld.SCI2Bits = sci2infobits;            % SCI2 information bits for PSSCH
    sld.SLSCHBits = slschinfobits;          % SL-SCH transport block

    sld.PSCCHSymbols = cresymbols(:,1);     % PSCCH symbols 
    sld.PSSCHSymbols = rdsymbols;           % PSSCH symbols, combined, in concatenated, mapping order
end


% Combined channel resource extraction, channel estimation and equalization
%
% Extract named physical channel resources, estimate propagation channel (or use perfect estimate), and MMSE equalize
function [chEqed,csi,noiseEst] = exqualize(carrier,rxGrid,chname,slo,decalgo)

    % Take resource grid, DM-RS and locations, and data locations of interest
    % Return equalized data and associated CSI
    
    % Carrier input is only used for CP, in the 60 kHz case
    if decalgo.PerfectChannelEstimator
        % Use the input estimates provided, rather than the above DM-RS based estimates...
        [estChannelGrid,noiseEst] = deal(decalgo.estChannelGrid,decalgo.noiseEst); 
    else
        % Get references for the named channel
        dmrsSymbols = slo.([chname,'DMRS']);
        dmrsIndices = slo.([chname,'DMRSIndices']);  
        [estChannelGrid,noiseEst] = nrChannelEstimate(carrier,rxGrid,dmrsIndices+1,dmrsSymbols,'CDMLengths',[size(dmrsSymbols,2) 1],'AveragingWindow',[0 1]);
    end

    % Get target resource elements from both the received grid and channel estimate grid
    [pdschRx,pdschHest] = nrExtractResources(slo.([chname,'Indices'])+1,rxGrid,estChannelGrid);
    
    % Equalization
    % Separate layers are containing in columns of chEqed and csi variables
    [chEqed,csi] = nrEqualizeMMSE(pdschRx,pdschHest,noiseEst);

end
