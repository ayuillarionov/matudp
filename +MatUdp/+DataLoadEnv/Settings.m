classdef Settings
    methods(Static)
        % subject, data, and data store root are mutually exclusive.
        % set only one.
        function setDataRoot(r)
            % root path under which lives dataStore/subject/dateStr
            setenv('MATUDP_DATAROOT', r);
            setenv('MATUDP_DATASTOREROOT');
            setenv('MATUDP_SUBJECTROOT');
        end
        
        function setDataStoreRoot(r)
            % root path under which lives subject/dateStr
            setenv('MATUDP_DATAROOT');
            setenv('MATUDP_DATASTOREROOT', r);
            setenv('MATUDP_SUBJECTROOT');
        end
        
        function setSubjectRoot(r)
            % root path under which lives dateStr
            setenv('MATUDP_DATAROOT');
            setenv('MATUDP_DATASTOREROOT');
            setenv('MATUDP_SUBJECTROOT', r);
        end
        
        function setSubject(r)
            setenv('MATUDP_SUBJECT', r);
        end
        
        function setProtocol(r)
            setenv('MATUDP_PROTOCOL', r);
        end
        
        function clear(~)
            setenv('MATUDP_DATAROOT');
            setenv('MATUDP_DATASTOREROOT');
            setenv('MATUDP_SUBJECTROOT');
            setenv('MATUDP_SUBJECT');
            setenv('MATUDP_PROTOCOL');
        end
    end
end