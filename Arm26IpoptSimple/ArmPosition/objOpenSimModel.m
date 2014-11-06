
function obj=objOpenSimModel(Pv)
%objOpenSimModel - function to be used in anonymous function for
%optimizer.  Given control input matrix, the objective will be returned.
%
%obj=objOpenSimModel(Pv)
%
%   Inputs:
%       Pv - A vector of Control Values (this is reshaped into a matrix,
%           vector is used because that it was is provided by IPOPT.
%           Vector is formated such that:
%               [C1@t0 C2@t0.. C1@t1 C2@t1.... C1@t3 C2@t3....]
%
%       Global Variables
%               m is used to store settings for the model evaluation:
%               m.osimModel - A refernce to the opensim model to be
%                       used.
%               m. controlsFunctionHandle:  A handle to model specific function that
%                   contains the calculations for the OpenSim Model controls.
%               m.timeSpan: The time span to integrate over
%                   (see IntegrateOpenSimPlant).
%                   [0 2] will integrate from 0 to 2 seconds.
%               m.integratorName: String containg the name of the integrator to be
%                   used.  For example: 'ode15s'
%               m.integratorOptions: Structure containing integrator options.  See
%                   ode15s for examples.
%                   integratorOptions = odeset('AbsTol', (1E-05), 'RelTol', (1E-03));
%               m.tp:  A vector of times at which the control values are provided.
%               m.saveLog: If a filename is provided
%
%
%   Outputs:
%       obj - objective scaler that is being minimzed

global m

display([datestr(now,13) ' Calculating Objective'])

m.osimModel.initSystem();

% Unflatten the controls vector to a matrix (columns are controls, rows are
% times for the spline

i=find(Pv>1);
Pv(i)=1;

i=find(Pv<0);
Pv(i)=0;

Pm=reshape(Pv,[],length(m.tp))';


if isequal(m.lastPm,Pm)
    modelResults = m.lastModelResults;
else
    modelResults = runOpenSimModel(m.osimModel, m.controlsFuncHandle,...
        m.timeSpan, m.integratorName, m.integratorOptions,m.tp,Pm, ...
        m.constObjFuncName);
    m.lastPm=Pm;
    m.lastModelResults=modelResults;
    m.lastGradObj=[];
    m.lastJacConst=[];
end

obj=modelResults.objective;


m.runCnt=m.runCnt+1;

% Update the bestYet
if m.bestYetValue<obj;
    m.bestYetValue=obj;
    m.bestYetIndex=m.runCnt;
end


display([datestr(now,13) ' Objective: ' sprintf('%f ',obj) '(' ...
    num2str(m.runCnt) ')']);

%Update the log file.
if ~isempty(m.saveLog)
    data.functionType=1;
    data.P=Pv;
    data.modelResults=modelResults;
    data.runCnt=m.runCnt;
    data.obj=obj;
    data.gradObj=[];
    data.constr=[];
    data.jacConst=[];
    data.time=now;
    data.bestYetValue=m.bestYetValue;
    varName=['log' num2str(m.runCnt)];
    eval([varName '=data;']);
    save(m.saveLog,varName,'-append')
end