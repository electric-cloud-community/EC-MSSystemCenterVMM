
// HyperVConfigList.java --
//
// HyperVConfigList.java is part of ElectricCommander.
//
// Copyright (c) 2005-2010 Electric Cloud, Inc.
// All rights reserved.
//

package ecplugins.hyperv.client;

import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.TreeMap;

import com.google.gwt.user.client.ui.ListBox;
import com.google.gwt.xml.client.Document;
import com.google.gwt.xml.client.Node;
import com.google.gwt.xml.client.XMLParser;

import static com.electriccloud.commander.gwt.client.util.XmlUtil.getNodeByName;
import static com.electriccloud.commander.gwt.client.util.XmlUtil.getNodeValueByName;
import static com.electriccloud.commander.gwt.client.util.XmlUtil.getNodesByName;

public class HyperVConfigList
{

    //~ Instance fields --------------------------------------------------------

    private final Map<String, HyperVConfigInfo> m_configInfo =
        new TreeMap<String, HyperVConfigInfo>();

    //~ Methods ----------------------------------------------------------------

    public void addConfig(
            String configName,
            String configUrl)
    {
        m_configInfo.put(configName, new HyperVConfigInfo(configUrl));
    }

    public String parseResponse(String cgiResponse)
    {
        Document document     = XMLParser.parse(cgiResponse);
        Node     responseNode = getNodeByName(document, "response");
        String   error        = getNodeValueByName(responseNode, "error");

        if (error != null && !error.isEmpty()) {
            return error;
        }

        Node       configListNode = getNodeByName(responseNode, "cfgs");
        List<Node> configNodes    = getNodesByName(configListNode, "cfg");

        for (Node configNode : configNodes) {
            String configName   = getNodeValueByName(configNode, "name");
            String configUrl = getNodeValueByName(configNode, "host");

            addConfig(configName, configUrl);
        }

        return null;
    }

    public void populateConfigListBox(ListBox lb)
    {

        for (String configName : m_configInfo.keySet()) {
            lb.addItem(configName);
        }
    }

    public Set<String> getConfigNames()
    {
        return m_configInfo.keySet();
    }

    public String getConfigHost(String configName)
    {
        return m_configInfo.get(configName).m_host;
    }

    public String getEditorDefinition(String configName)
    {
        return "EC-MSSystemCenterVMM";
    }

    public boolean isEmpty()
    {
        return m_configInfo.isEmpty();
    }

    public void setEditorDefinition(
            String configUrl,
            String editorDefiniton)
    {
    }

    //~ Inner Classes ----------------------------------------------------------

    private class HyperVConfigInfo
    {

        //~ Instance fields ----------------------------------------------------

        private String m_host;

        //~ Constructors -------------------------------------------------------

        public HyperVConfigInfo(String host)
        {
            m_host = host;
        }
    }
}
