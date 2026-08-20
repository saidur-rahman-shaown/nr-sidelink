classdef HARQEntitySL < handle
%   HQE = HARQEntitySL(HIDSEQ,RVSEQ,NTB,BHRQ) creates a HARQ entity 
%   object, HQE, to manage a set of parallel HARQ processes for a 
%   single UE. HIDSEQ defines the fixed sequence of HARQ process IDs 
%   scheduling the stop-and-wait protocol. Optional RVSEQ specifies the RV
%   sequence used for the initial transport block transmissions and any 
%   subsequent retransmissions (default is RV=0, with no retransmissions).
%   Optional NTB specifies the number of transport blocks to manage for 
%   each process (default is 1). Optional logical BHRQ specifies whether
%   blind HARQ retransmissions are to be sent without reacting to 
%   transmission error feedback. A HARQEntitySL object is a handle object
%   representing one HARQ entity per DL-SCH/UL-SCH/SL-SCH transport channel
%   per UE MAC entity.
%
%   HARQ information for DL-SCH, UL-SCH, or SL-SCH transmissions consists
%   of, new data indicator (NDI), transport block size (TBS), redundancy 
%   version (RV), and HARQ process ID. A HARQEntitySL object stores the 
%   HARQ information for each of a set of parallel HARQ processes. Only one
%   process is active for data transmission at a time. The object steps
%   through these processes using a fixed sequence and the object 
%   properties contain the HARQ information for the currently active 
%   process. The TBS and CRC error of the associated data transmission 
%   update the current HARQ process state.
% 
%   HARQEntitySL properties (Read-only):
% 
%   HARQProcessID        - Current HARQ process ID
%   TransportBlockSize   - Current TBS for process, per codeword
%   TransmissionNumber   - Current transmission number in RV sequence, per codeword (0-based)
%   RedundancyVersion    - Current redundancy version, per codeword
%   TransmissionSuccess  - Has a transmission already succeeded on this open process, per codeword (blind HARQ)
%   NewData              - Is this new transport data for the process i.e. is this the start of a new RV sequence?
%   SequenceTimeout      - Is this new data because of timeout i.e. last sequence ended without a successful transmission?
%   MinNumTransmissions  - Minimum number of transmissions possible in a process sequence 
%   MaxNumTransmissions  - Maximum number of transmissions possible in a process sequence 
%   TotalBlocksAllProcesses      - Total number of transport blocks sent/received across all processes
%   SuccessfulBlocksAllProcesses - Total number of transport blocks received successfully across all processes      
%   TotalBitsAllProcesses        - Total number of information bits sent/received across all processes
%   SuccessfulBitsAllProcesses   - Total number of information received successfully across all processes
%
%   HARQEntitySL methods:
%
%   HARQEntitySL         - Create a HARQEntitySL object
%   updateProcess        - Update current HARQ process with data transmission information (TBS, CRC error, bit capacity)
%   advanceToNextProcess - Advance entity to next HARQ process in the sequence
%   updateAndAdvance     - Update current HARQ process and advance to the next process

%   Copyright 2021-2023 The MathWorks, Inc.
   
    properties (SetAccess = private)
        HARQProcessID;       % Current HARQ process ID
        TransportBlockSize   % Current TBS, per codeword
        TransmissionNumber;  % Current transmission number in RV sequence (0-based)
        RedundancyVersion;   % Current redundancy version
        
        TransmissionSuccess; % Has a transmission already succeeded on this open process (blind HARQ)
        NewData;             % Is this the start of a new RV sequence?
        SequenceTimeout;     % Is this a new sequence because of timeout i.e. is the last sequence end without a successful transmission?

        MinNumTransmissions; % Minimum number of transmissions possible in a process sequence 
        MaxNumTransmissions; % Maximum number of transmissions possible in a process sequence 
    end
    
    properties (SetAccess = private)
        TotalBlocksAllProcesses;       % Total number of transport blocks sent/received across all processes
        SuccessfulBlocksAllProcesses;  % Total number of transport blocks received successfully across all processes
       
        TotalBitsAllProcesses;         % Total number of information bits sent/received across all processes
        SuccessfulBitsAllProcesses;    % Total number of information received successfully across all processes
    end

    properties (Access = private)
        HarqProcessIDOrder;        % HARQ process ID sequence order to be used
        HarqRVSequence;            % RV sequence shared by all processes

        HarqProcessStateOrder;     % HARQ process sequence state order (maps the ID order into state array)
        HarqProcessStates;         % Array of state information for the individual processes
        HarqProcessIndex;          % Current index into the HARQ process sequence order
        HarqOpenLoop;              % Open loop, or closed loop
    end

    methods

        function obj = HARQEntitySL(processorder,rvsequence,ncw,blind)
        %HARQEntitySL Create a HARQEntitySL object for a fixed process sequence
        %   HQE = HARQEntitySL(HIDSEQ,RVSEQ,NTB,BHRQ) creates a HARQ entity object, HQE,
        %   to manage a set of parallel HARQ processes for a single UE. 
        %   HIDSEQ defines the fixed sequence of HARQ process IDs scheduling the
        %   stop-and-wait protocol. Optional RVSEQ specifies the RV sequence used
        %   for the initial transport block transmissions and any subsequent
        %   retransmissions (default is RV=0, with no retransmissions). Optional
        %   NTB specifies the number of transport blocks to manage for each process
        %   (default is 1). Optional logical BHARQ specifies whether blind HARQ 
        %   retransmissions are to be sent without reacting to transmission
        %   error feedback. A HARQEntitySL object is a handle object representing
        %   one HARQ entity per DL-SCH/UL-SCH/SL-SCH transport channel per UE MAC entity.
            
            if nargin < 4
                blind = 0;
                if nargin < 3
                    ncw = 1;    % Default to managing a single codeword
                    if nargin < 2
                        rvsequence = 0;  % Default to no HARQ retransmissions (initial transmission only)
                    end
                end
            end

            % Store the common RV sequence for all processes
            obj.HarqRVSequence = rvsequence;     % Share the same RV sequence per CW and across all processes
     
            % Store open-loop blind HARQ processing mode
            obj.HarqOpenLoop = logical(blind);

            % Transmission sequence length bounds
            obj.MinNumTransmissions = ~obj.HarqOpenLoop + obj.HarqOpenLoop*length(rvsequence);
            obj.MaxNumTransmissions = length(rvsequence);

            % Store the HARQ process fixed sequence order 
            obj.HarqProcessIDOrder = processorder;
            % Get the number of unique processes in the sequence 
            % and a 1-based index for each process ID, which will be 
            % used to link each ID to its individual process state
            [processids,~,obj.HarqProcessStateOrder] = unique(obj.HarqProcessIDOrder);        
    
            % Create array of HARQ process states for the set of the processes
            processstate.RVIdx = zeros(1,ncw);      % Indices into RV sequence for codewords
            processstate.Timeout = zeros(1,ncw);    % Indication of previous RV sequence timeout
            processstate.TBS = zeros(1,ncw);        % Transport block sizes
            processstate.TransmissionSuccess = zeros(1,ncw);   % Rolling TrBlk error state
            obj.HarqProcessStates = repmat(processstate,numel(processids),1);  % Create array
    
            % Initialise current process index and load its state into the public properties
            obj.HarqProcessIndex = 1;
            dereferenceProcessIndex(obj);
    
            % Clear block transmission counters
            obj.TotalBlocksAllProcesses = zeros(1,ncw);
            obj.SuccessfulBlocksAllProcesses = zeros(1,ncw);
            obj.TotalBitsAllProcesses = zeros(1,ncw);
            obj.SuccessfulBitsAllProcesses = zeros(1,ncw);
        end   
        
        function rep = updateProcess(obj,txerror,tbs,g)
        %updateProcess Update current HARQ process on data transmission
        %   TR = updateProcess(HE,BLKERR,TBS,G) updates the current HARQ process with
        %   the per-transport block CRC error, BLKERR, transport block size, TBS, and
        %   bit capacity, G, of the associated data transmission. TR is a text
        %   update report of the result of the data transmission on the process state.
        %  
        %   Example:
        %   harqidseq = 0:15;
        %   rvseq = [0 2 3 1];
        %   harqent1 = HARQEntitySL(harqidseq,rvseq)
        %   urep1 = updateProcess(harqent1,1,100,300);
        %   urep1
        %   harqent1
        % 
        %   harqent2 = HARQEntitySL(harqidseq,rvseq,2)
        %   urep2 = updateProcess(harqent2,[1 0],[100 200],[300 600]);
        %   urep2
        %   harqent2
        %
        %   See also updateAndAdvance.

            % Process the result of the _current_ transmission, given the
            % combination of the shared channel configuration (subset) and
            % the resulting CRC error
            if nargout
                rep = createUpdateReport(obj,txerror,tbs,g);
            end

            % Create a text summary of what happened for the transmission event
            % for the current process 

            % Update current HARQ process information (this updates the RV
            % depending on CRC pass or fail in the previous transmission for
            % this HARQ process)

            % Get index for current process in the state array 
            stateidx = obj.HarqProcessStateOrder(obj.HarqProcessIndex);

            % Capture the TBS values of any new data transmissions that occurred in this transmission event
            obj.HarqProcessStates(stateidx).TBS(obj.NewData) = tbs(obj.NewData);

            % Check that the TBS values of any retransmissions are the same as the initial transmission
            d = (tbs ~= obj.HarqProcessStates(stateidx).TBS) & ~obj.NewData;
            if any(d)
                warning('For HARQ process %d, transport block sizes of a retransmission (%s) changed from the initial transmission (%s).',...
                     obj.HARQProcessID,...
                     join(string(tbs(d)),','),...
                     join(string(obj.HarqProcessStates(stateidx).TBS(d)),','));
            end

            % Update process information given the reporting transmission error state, ready for the _next_ transmission
            
            % Blind open-loop HARQ or closed-loop feedback directed mode
            openloop = ~isempty(obj.HarqOpenLoop) && logical(obj.HarqOpenLoop);

            % Get RV indices for current process in the RV sequence
            rvidx = obj.HarqProcessStates(stateidx).RVIdx;

            % If error, advance and check for timeout, otherwise set to 0
            inerror = txerror ~= zeros(size(rvidx));        % Allow 'scalar expansion' of error across codewords

            % Update rvidx on input error information
            effectiveerror = openloop | inerror;            % If open-loop then signal an error to keep the process moving
            rvidx(~effectiveerror) = 0;                     % Reset sequence indices if NO error (transport success)
            rvidx = rvidx + effectiveerror;                 % OR increment RV sequence if error

            % Test for end of sequence now being reached
            timeout = rvidx == length(obj.HarqRVSequence);      % Test for a sequence timeout when we increment
            rvidx(timeout) = 0;                                 % And reset any effected by timeout

            % Accumulated transmission success is whether the process has passed already (open-loop case) or passed on this transmission
            accumulatedsuccess = obj.HarqProcessStates(stateidx).TransmissionSuccess | ~inerror;

            recordevent = ~openloop | timeout;              % This counts as an overall statistics recording event if closed-loop OR if open-loop and we hit the end of the RV sequence
            passevent = recordevent & accumulatedsuccess;   % Does this count as a block transmission pass event

            accumulatedsuccess(rvidx==0) = 0;   % Clear overall process success flag if back at beginning of RV sequence
            obj.HarqProcessStates(stateidx).TransmissionSuccess = accumulatedsuccess;

            % Capture results into process state
            obj.HarqProcessStates(stateidx).RVIdx = rvidx;
            obj.HarqProcessStates(stateidx).Timeout = timeout;

            % Assume that each method call is for a separate transmission event
            obj.SuccessfulBlocksAllProcesses = obj.SuccessfulBlocksAllProcesses + passevent;   % Open loop : Used accumulatederror at the end of the sequence, close loop : Use 
            obj.TotalBlocksAllProcesses = obj.TotalBlocksAllProcesses + recordevent;

            obj.SuccessfulBitsAllProcesses = obj.SuccessfulBitsAllProcesses + tbs.*passevent;   % Accumulate the TBS 
            obj.TotalBitsAllProcesses = obj.TotalBitsAllProcesses + tbs.*recordevent;

            % Reflect updated state back into the public properties
            dereferenceProcessIndex(obj);

        end
        
        function advanceToNextProcess(obj)
        %advanceToNextProcess Advance to next HARQ process in process ID sequence
        %   advanceToNextProcess(HE) moves the HARQ entity on to the next process in
        %   the HARQ ID sequence. The object properties are updated with the new 
        %   process HARQ information state.
        %
        %   See also updateAndAdvance.

            % Update process index in the ID sequence order
            obj.HarqProcessIndex = mod(obj.HarqProcessIndex,length(obj.HarqProcessIDOrder))+1;  % 1-based
                        
            % Reflect updated state back into the public properties
            dereferenceProcessIndex(obj);
        end

        function varargout = updateAndAdvance(obj,error,tbs,g)
        %updateAndAdvance Update current HARQ process and advance to next process
        %   TR = updateAndAdvance(HE,BLKERR,TBS,G) updates the current HARQ process 
        %   with associated data transmission, and advance to the next process
        %   in the HARQ process ID sequence. The current process is updated with
        %   the per-transport block CRC error, BLKERR, transport block size, TBS, and
        %   bit capacity, G, of the associated data transmission. TR is a text
        %   update report of the result of the data transmission on the process state.
        %
        %   See also updateProcess, advanceToNextProcess.

            [varargout{1:nargout}] = updateProcess(obj,error,tbs,g);
            advanceToNextProcess(obj);
        end

    end

    methods (Access = private)
        
        % Reflect current state back in the public properties
        function dereferenceProcessIndex(obj)
            
            % Load the current indexed process state into the public properties
            obj.HARQProcessID = obj.HarqProcessIDOrder(obj.HarqProcessIndex);       % Current HARQ process ID

            stateidx = obj.HarqProcessStateOrder(obj.HarqProcessIndex);
 
            obj.TransportBlockSize = obj.HarqProcessStates(stateidx).TBS;           % Current TBS
            obj.TransmissionNumber = obj.HarqProcessStates(stateidx).RVIdx;         % Current transmission number in sequence
            obj.RedundancyVersion = obj.HarqRVSequence(obj.TransmissionNumber + 1); % Current redundancy version

            obj.NewData = obj.TransmissionNumber == 0;                              % Is this the start of a new sequence?
            obj.SequenceTimeout = obj.HarqProcessStates(stateidx).Timeout;          % Did the last sequence end without a successful transmission

            obj.TransmissionSuccess = obj.HarqProcessStates(stateidx).TransmissionSuccess;  % Has there already been a successful transmission on an open process
        end
        
        % Create a text report of the effect of the data transmission on the current HARQ process
        function sr = createUpdateReport(HARQEntitySL,blkerr,tbs,g)
            
            % Display transport block CRC error information per codeword managed by current HARQ process
            icr = tbs./g;    % Instantaneous code rate
            blkerr = logical(blkerr);
            
            % Leading part
            strparts = sprintf("HARQ Proc %d:%s",HARQEntitySL.HARQProcessID,blanks(HARQEntitySL.HARQProcessID<10));
    
            estrings = ["passed","FAILED"];
            for cw=1:length(HARQEntitySL.NewData)
                % Create a report on the RV state given position in RV sequence and decoding error
    
                % Transmission number part
                if HARQEntitySL.NewData(cw)
                    ts1 = sprintf("Initial transmission");
                else
                    ts1 = sprintf("Retransmission #%d",HARQEntitySL.TransmissionNumber(cw));
                end
    
                % Transmission result part
                ts2 = estrings{1+blkerr(cw)};
                % If open loop, and a transmission has already succeeded on the process
                % then report on that success, rather than the pointwise blkerr input
                if HARQEntitySL.HarqOpenLoop
                    % Get index for current process in the state array
                    stateidx = HARQEntitySL.HarqProcessStateOrder(HARQEntitySL.HarqProcessIndex);
                    if HARQEntitySL.HarqProcessStates(stateidx).TransmissionSuccess(cw)
                        ts2 = "(TB already passed)";
                        % If already block success then use that for a string, rather than input
                    end
                end

                % Trailing parameter info part
                ts3 = sprintf("(RV=%d,TBS=%d,G=%d,CR=%f)",HARQEntitySL.RedundancyVersion(cw),tbs(cw),g(cw),icr(cw));   % For existing info, would need csn and icr
              
                % Add codeword prefix report to list of string parts
                strparts(end+1) = sprintf("CW%d: %s %s %s.",cw-1,ts1,ts2,ts3); %#ok<AGROW> 
            end
    
            % Combine all string parts
            sr = join(strparts,' ');
        
        end   
    end
   
end
